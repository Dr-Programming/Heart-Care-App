package com.heartcare.admin.research;

import com.heartcare.admin.model.AdminUser;
import com.heartcare.admin.repository.AdminUserRepository;
import com.heartcare.common.exception.BadRequestException;
import com.heartcare.common.exception.ConflictException;
import com.heartcare.common.exception.ResourceNotFoundException;
import com.heartcare.research.dto.GrantView;
import com.heartcare.research.model.Researcher;
import com.heartcare.research.model.ResearcherGrant;
import com.heartcare.research.model.ResearcherStatus;
import com.heartcare.research.repository.ResearchSettingsRepository;
import com.heartcare.research.repository.ResearcherEventRepository;
import com.heartcare.research.repository.ResearcherEventRepository.Action;
import com.heartcare.research.repository.ResearcherGrantRepository;
import com.heartcare.research.repository.ResearcherRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Everything an admin can do to a researcher account. Every change is written to
 * researcher_admin_events alongside the change itself, in the same transaction.
 */
@Service
public class AdminResearcherService {

    private static final Logger audit = LoggerFactory.getLogger("admin-audit");

    private final ResearcherRepository researchers;
    private final ResearcherGrantRepository grants;
    private final ResearcherEventRepository events;
    private final ResearchSettingsRepository settings;
    private final AdminUserRepository admins;
    private final PasswordEncoder passwordEncoder;
    private final PasswordGenerator passwordGenerator;
    private final ObjectMapper objectMapper;

    public AdminResearcherService(ResearcherRepository researchers, ResearcherGrantRepository grants,
                                  ResearcherEventRepository events, ResearchSettingsRepository settings,
                                  AdminUserRepository admins, PasswordEncoder passwordEncoder,
                                  PasswordGenerator passwordGenerator, ObjectMapper objectMapper) {
        this.researchers = researchers;
        this.grants = grants;
        this.events = events;
        this.settings = settings;
        this.admins = admins;
        this.passwordEncoder = passwordEncoder;
        this.passwordGenerator = passwordGenerator;
        this.objectMapper = objectMapper;
    }

    /** The working list: active and revoked researchers. Archived ones live in {@link #archive()}. */
    @Transactional(readOnly = true)
    public List<ResearcherView> list() {
        return views(researchers.findByStatusNotOrderByCreatedAtDesc(ResearcherStatus.ARCHIVED));
    }

    @Transactional(readOnly = true)
    public List<ResearcherView> archive() {
        return views(researchers.findByStatusOrderByArchivedAtDesc(ResearcherStatus.ARCHIVED));
    }

    private List<ResearcherView> views(List<Researcher> list) {
        Map<UUID, ResearcherGrant> byId = new LinkedHashMap<>();
        grants.findAll().forEach(g -> byId.put(g.getResearcherId(), g));
        Map<UUID, String> adminNames = adminNames();
        return list.stream().map(r -> view(r, byId.get(r.getId()), adminNames)).toList();
    }

    /**
     * The admin's "delete". Nothing is removed: the account is frozen and moved to the archive so
     * its activity log keeps a subject for audits, and its username stays reserved.
     */
    @Transactional
    public ResearcherView archive(UUID id, String reason, UUID adminId) {
        Researcher r = require(id);
        if (r.isArchived()) {
            throw new BadRequestException("This researcher is already archived");
        }
        r.archive(reason.trim(), adminId, OffsetDateTime.now(ZoneOffset.UTC));
        record(id, adminId, Action.ARCHIVED, Map.of("reason", reason.trim()));
        return view(r, grants.findById(id).orElse(null), adminNames());
    }

    @Transactional
    public ResearcherView unarchive(UUID id, UUID adminId) {
        Researcher r = require(id);
        if (!r.isArchived()) {
            throw new BadRequestException("This researcher isn't archived");
        }
        r.unarchive(OffsetDateTime.now(ZoneOffset.UTC));
        record(id, adminId, Action.UNARCHIVED, null);
        return view(r, grants.findById(id).orElse(null), adminNames());
    }

    @Transactional(readOnly = true)
    public ResearcherView get(UUID id) {
        Researcher r = require(id);
        return view(r, grants.findById(id).orElse(null), adminNames());
    }

    @Transactional
    public IssuedPassword create(CreateResearcherRequest request, UUID adminId) {
        validate(request.grant());
        String username = request.username().trim();
        if (researchers.existsByUsername(username)) {
            throw new ConflictException("Username is already taken");
        }
        String password = passwordGenerator.generate();
        Researcher researcher = new Researcher(username, request.fullName().trim(),
                blankToNull(request.organisation()), passwordEncoder.encode(password), adminId);
        try {
            researchers.saveAndFlush(researcher);
        } catch (DataIntegrityViolationException ex) {
            throw new ConflictException("Username is already taken");
        }
        ResearcherGrant grant = new ResearcherGrant(researcher.getId());
        apply(grant, request.grant(), adminId);
        grants.saveAndFlush(grant);

        Map<String, Object> details = new LinkedHashMap<>();
        details.put("username", username);
        details.put("grant", request.grant());
        record(researcher.getId(), adminId, Action.CREATED, details);
        return new IssuedPassword(view(researcher, grant, adminNames()), password);
    }

    @Transactional
    public ResearcherView updateGrant(UUID id, GrantRequest request, UUID adminId) {
        validate(request);
        Researcher r = requireEditable(id);
        ResearcherGrant grant = grants.findById(id).orElseGet(() -> new ResearcherGrant(id));
        GrantView before = grant.getUpdatedAt() == null ? null : GrantView.of(grant);
        apply(grant, request, adminId);
        grants.saveAndFlush(grant);
        Map<String, Object> details = new LinkedHashMap<>();
        details.put("before", before);
        details.put("after", request);
        record(id, adminId, Action.GRANT_UPDATED, details);
        return view(r, grant, adminNames());
    }

    @Transactional
    public ResearcherView revoke(UUID id, UUID adminId) {
        Researcher r = requireEditable(id);
        if (r.getStatus() == ResearcherStatus.REVOKED) {
            throw new BadRequestException("Access is already revoked");
        }
        r.revoke(OffsetDateTime.now(ZoneOffset.UTC));
        record(id, adminId, Action.REVOKED, null);
        return view(r, grants.findById(id).orElse(null), adminNames());
    }

    @Transactional
    public ResearcherView restore(UUID id, UUID adminId) {
        Researcher r = requireEditable(id);
        if (r.getStatus() == ResearcherStatus.ACTIVE) {
            throw new BadRequestException("Access is already active");
        }
        r.restore();
        record(id, adminId, Action.RESTORED, null);
        return view(r, grants.findById(id).orElse(null), adminNames());
    }

    /** New admin-issued password: ends every session and grants one more self-service change. */
    @Transactional
    public IssuedPassword resetPassword(UUID id, UUID adminId) {
        Researcher r = requireEditable(id);
        String password = passwordGenerator.generate();
        r.issuePassword(passwordEncoder.encode(password));
        record(id, adminId, Action.PASSWORD_RESET, null);
        return new IssuedPassword(view(r, grants.findById(id).orElse(null), adminNames()), password);
    }

    @Transactional(readOnly = true)
    public List<ResearcherEventRepository.Row> events(UUID id) {
        require(id);
        return events.forResearcher(id);
    }

    @Transactional(readOnly = true)
    public int minGroupSize() {
        return settings.minGroupSize();
    }

    @Transactional
    public int setMinGroupSize(int k, UUID adminId) {
        int before = settings.minGroupSize();
        settings.setMinGroupSize(k);
        audit.info("admin={} research min_group_size {} -> {}", adminId, before, k);
        return k;
    }

    private void record(UUID researcherId, UUID adminId, Action action, Object details) {
        events.insert(researcherId, adminId, action, details == null ? null : objectMapper.writeValueAsString(details));
        audit.info("admin={} researcher={} {}", adminId, researcherId, action);
    }

    private static void validate(GrantRequest g) {
        if (g.dataFrom() != null && g.dataTo() != null && g.dataFrom().isAfter(g.dataTo())) {
            throw new BadRequestException("dataFrom must be on or before dataTo");
        }
        if (g.datasets().isEmpty()) {
            throw new BadRequestException("Grant at least one dataset");
        }
    }

    private static void apply(ResearcherGrant grant, GrantRequest g, UUID adminId) {
        grant.update(g.accessLevel(), g.datasets(), g.exportAllowed(), g.dataFrom(), g.dataTo(), g.expiresAt(), adminId);
    }

    private Researcher require(UUID id) {
        return researchers.findById(id).orElseThrow(() -> new ResourceNotFoundException("Researcher not found"));
    }

    private Researcher requireEditable(UUID id) {
        Researcher r = require(id);
        if (r.isArchived()) {
            throw new BadRequestException("This researcher is archived. Restore them from the archive first.");
        }
        return r;
    }

    private Map<UUID, String> adminNames() {
        Map<UUID, String> names = new LinkedHashMap<>();
        for (AdminUser a : admins.findAll()) {
            names.put(a.getId(), a.getUsername());
        }
        return names;
    }

    private static ResearcherView view(Researcher r, ResearcherGrant g, Map<UUID, String> adminNames) {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        return new ResearcherView(
                r.getId().toString(), r.getUsername(), r.getFullName(), r.getOrganisation(), r.getStatus(),
                g != null && g.isExpired(now), r.isMustChangePassword(), r.canSelfChangePassword(),
                r.getPasswordChangedAt(), r.getCreatedAt(),
                r.getCreatedByAdminId() == null ? null : adminNames.get(r.getCreatedByAdminId()),
                r.getRevokedAt(), r.getLastLoginAt(), g == null ? null : GrantView.of(g),
                r.getArchivedAt(), r.getArchivedBy() == null ? null : adminNames.get(r.getArchivedBy()),
                r.getArchiveReason());
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
