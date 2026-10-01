package com.heartcare.medication.model;

/**
 * How often a medication is taken, and therefore how many schedule times it must carry. A BID
 * medication with three times would fire three reminders and count three doses as due.
 */
public enum Frequency {
    ONCE_DAILY(1, 1),
    BID(2, 2),
    TID(3, 3),
    /** Free-form schedule. Zero times is valid: the mobile app treats it as "as needed". */
    CUSTOM(0, 12);

    private final int minTimes;
    private final int maxTimes;

    Frequency(int minTimes, int maxTimes) {
        this.minTimes = minTimes;
        this.maxTimes = maxTimes;
    }

    public boolean allowsTimeCount(int count) {
        return count >= minTimes && count <= maxTimes;
    }

    /** Human-readable rule for error messages, e.g. "BID needs exactly 2 schedule times". */
    public String timeCountRule() {
        return minTimes == maxTimes
                ? name() + " needs exactly " + minTimes + (minTimes == 1 ? " schedule time" : " schedule times")
                : name() + " needs " + minTimes + " to " + maxTimes + " schedule times";
    }
}
