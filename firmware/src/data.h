#pragma once
#include <Arduino.h>

struct UsageData {
    float session_pct;       // utilization 0-100 (5h window Pro/Max; spending % Enterprise)
    int session_reset_mins;  // minutes until reset
    float weekly_pct;        // 7-day utilization (Pro/Max only; 0 for Enterprise)
    int weekly_reset_mins;   // minutes until weekly reset (Pro/Max only)
    char status[16];         // "allowed", "limited", etc.
    bool chime;              // play the session-reset chime; false unless daemon opts in
    bool enterprise;         // true = Enterprise spending-limit account
    int time_pct;            // 0-100: fraction of billing period elapsed (Enterprise)
    int period_days;         // total billing period length in days (Enterprise)
    char reset_date[12];     // formatted reset date e.g. "Jul 1" (Enterprise)
    long clock_epoch;        // local wall-clock epoch (s) from daemon; 0 = not provided
    int  clock_fmt;          // 12 or 24 (hour format from daemon); defaults to 24
    bool  has_model;         // daemon sent a per-model weekly limit ("m")
    float model_pct;         // that limit's 7-day utilization 0-100
    int   model_reset_mins;  // minutes until it resets
    char  model_label[12];   // pill text, e.g. "Fable"
    bool   has_month;        // daemon sent this month's totals ("mt"/"mc")
    double month_tokens;     // tokens this calendar month (can exceed 2^31)
    float  month_cost;       // API-equivalent USD for those tokens
    bool ok;                 // data parse succeeded
    bool valid;              // false until first successful parse
};
