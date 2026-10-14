// Entry rules for verifyQualification. Mirrors lib/raffle/qualifier_rules.dart —
// keep the two in sync.

const QUALIFIER_SECONDS = 300; // 5 minutes of active play per entry

function dayKeyOf(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

// Days of the month before `now` that have no entry yet, oldest first.
function getMissedDays(record, now) {
  const earned = new Set([...(record.qualifiedDays || []), ...(record.catchupDays || [])]);
  const missed = [];
  for (let d = 1; d < now.getDate(); d++) {
    const key = dayKeyOf(new Date(now.getFullYear(), now.getMonth(), d));
    if (!earned.has(key)) missed.push(key);
  }
  return missed;
}

// Banks `activeSeconds` onto the day's running total and grants entries. Every
// full 300s of play that day is one entry: the first block qualifies the day,
// each further block earns the oldest missed day. Mutates and returns `record`.
function applyBlocks(record, dayKey, activeSeconds, now) {
  record.qualifiedDays = record.qualifiedDays || [];
  record.catchupDays = record.catchupDays || [];
  record.dailyActiveSeconds = record.dailyActiveSeconds || {};

  const bankedBefore = record.dailyActiveSeconds[dayKey] || 0;
  const todayTotal = bankedBefore + activeSeconds;
  record.dailyActiveSeconds[dayKey] = todayTotal;

  let blocks = Math.floor(todayTotal / QUALIFIER_SECONDS) - Math.floor(bankedBefore / QUALIFIER_SECONDS);
  let entryGranted = false;
  let catchupApplied = false;

  // Also covers a day with 5+ minutes banked that was never marked qualified.
  const meetsThreshold = todayTotal >= QUALIFIER_SECONDS;
  if (meetsThreshold && !record.qualifiedDays.includes(dayKey)) {
    record.qualifiedDays = [...record.qualifiedDays, dayKey];
    entryGranted = true;
    if (blocks > 0) blocks--;
  }

  if (blocks > 0) {
    const missed = getMissedDays(record, now);
    for (let i = 0; i < blocks && i < missed.length; i++) {
      record.catchupDays = [...record.catchupDays, missed[i]];
      entryGranted = true;
      catchupApplied = true;
    }
  }

  return { meetsThreshold, entryGranted, catchupApplied };
}

module.exports = { QUALIFIER_SECONDS, getMissedDays, applyBlocks };
