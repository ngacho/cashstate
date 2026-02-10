import { useState } from "react";

const COLORS = {
  mint: "#00D09C",
  mintDark: "#00B386",
  mintLight: "#E6FAF5",
  mintGlow: "rgba(0, 208, 156, 0.15)",
  dark: "#1A1D23",
  darkCard: "#22262E",
  darkBorder: "#2E333D",
  textPrimary: "#F0F2F5",
  textSecondary: "#8B93A1",
  red: "#FF6B6B",
  orange: "#FFB84D",
  blue: "#5B8DEF",
  purple: "#A78BFA",
};

const categories = [
  { name: "Housing", spent: 1850, budget: 2000, color: COLORS.blue, icon: "🏠" },
  { name: "Food & Dining", spent: 620, budget: 500, color: COLORS.red, icon: "🍽️" },
  { name: "Transportation", spent: 180, budget: 300, color: COLORS.mint, icon: "🚗" },
  { name: "Entertainment", spent: 95, budget: 150, color: COLORS.purple, icon: "🎬" },
  { name: "Shopping", spent: 340, budget: 250, color: COLORS.orange, icon: "🛍️" },
  { name: "Utilities", spent: 210, budget: 250, color: "#5ED4F5", icon: "⚡" },
];

const transactions = [
  { name: "Whole Foods Market", category: "Food & Dining", amount: -67.43, date: "Today", icon: "🥑" },
  { name: "Netflix", category: "Entertainment", amount: -15.99, date: "Today", icon: "📺" },
  { name: "Shell Gas Station", category: "Transportation", amount: -42.18, date: "Yesterday", icon: "⛽" },
  { name: "Payroll Deposit", category: "Income", amount: 3250.00, date: "Yesterday", icon: "💰" },
  { name: "Amazon", category: "Shopping", amount: -89.99, date: "Feb 6", icon: "📦" },
  { name: "Starbucks", category: "Food & Dining", amount: -6.75, date: "Feb 6", icon: "☕" },
  { name: "Electric Company", category: "Utilities", amount: -124.50, date: "Feb 5", icon: "💡" },
  { name: "Spotify", category: "Entertainment", amount: -10.99, date: "Feb 5", icon: "🎵" },
  { name: "Target", category: "Shopping", amount: -53.22, date: "Feb 4", icon: "🎯" },
  { name: "Freelance Payment", category: "Income", amount: 800.00, date: "Feb 3", icon: "💻" },
];

const monthlyData = [
  { month: "Sep", income: 5200, spending: 3800 },
  { month: "Oct", income: 5400, spending: 4100 },
  { month: "Nov", income: 5200, spending: 4600 },
  { month: "Dec", income: 6100, spending: 5200 },
  { month: "Jan", income: 5400, spending: 3900 },
  { month: "Feb", income: 5200, spending: 3295 },
];

const accounts = [
  { name: "Chase Checking", balance: 4280.50, type: "checking", icon: "🏦" },
  { name: "Ally Savings", balance: 12450.00, type: "savings", icon: "🐖" },
  { name: "Visa Credit Card", balance: -1840.25, type: "credit", icon: "💳" },
  { name: "Fidelity 401(k)", balance: 45200.00, type: "investment", icon: "📈" },
];

function ProgressBar({ percent, color, height = 6 }) {
  const clamped = Math.min(percent, 100);
  const over = percent > 100;
  return (
    <div style={{
      width: "100%", height, borderRadius: height,
      background: COLORS.darkBorder, overflow: "hidden", position: "relative"
    }}>
      <div style={{
        width: `${clamped}%`, height: "100%", borderRadius: height,
        background: over ? COLORS.red : color,
        transition: "width 0.8s cubic-bezier(0.4, 0, 0.2, 1)",
        boxShadow: over ? `0 0 8px ${COLORS.red}40` : `0 0 8px ${color}30`
      }} />
    </div>
  );
}

function MiniChart({ data, width = 120, height = 40, color = COLORS.mint }) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const points = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / range) * (height - 4) - 2;
    return `${x},${y}`;
  }).join(" ");

  return (
    <svg width={width} height={height} style={{ display: "block" }}>
      <defs>
        <linearGradient id={`grad-${color.replace('#','')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.3" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <polygon
        points={`0,${height} ${points} ${width},${height}`}
        fill={`url(#grad-${color.replace('#','')})`}
      />
      <polyline points={points} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function BarChart({ data }) {
  const maxVal = Math.max(...data.map(d => Math.max(d.income, d.spending)));
  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 12, height: 140, padding: "0 4px" }}>
      {data.map((d, i) => (
        <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
          <div style={{ display: "flex", gap: 3, alignItems: "flex-end", height: 110 }}>
            <div style={{
              width: 14, borderRadius: "4px 4px 2px 2px",
              height: `${(d.income / maxVal) * 100}%`,
              background: `linear-gradient(180deg, ${COLORS.mint}, ${COLORS.mintDark})`,
              transition: "height 0.6s ease",
              transitionDelay: `${i * 0.05}s`
            }} />
            <div style={{
              width: 14, borderRadius: "4px 4px 2px 2px",
              height: `${(d.spending / maxVal) * 100}%`,
              background: `linear-gradient(180deg, ${COLORS.textSecondary}60, ${COLORS.textSecondary}30)`,
              transition: "height 0.6s ease",
              transitionDelay: `${i * 0.05 + 0.1}s`
            }} />
          </div>
          <span style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>{d.month}</span>
        </div>
      ))}
    </div>
  );
}

function DonutChart({ segments, size = 160 }) {
  const total = segments.reduce((s, seg) => s + seg.value, 0);
  const strokeWidth = 18;
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;

  return (
    <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
      <circle cx={size/2} cy={size/2} r={radius} fill="none" stroke={COLORS.darkBorder} strokeWidth={strokeWidth} />
      {segments.map((seg, i) => {
        const pct = seg.value / total;
        const dash = pct * circumference;
        const gap = circumference - dash;
        const currentOffset = offset;
        offset += dash;
        return (
          <circle key={i} cx={size/2} cy={size/2} r={radius} fill="none"
            stroke={seg.color} strokeWidth={strokeWidth}
            strokeDasharray={`${dash} ${gap}`}
            strokeDashoffset={-currentOffset}
            strokeLinecap="round"
            style={{ transition: "stroke-dasharray 0.8s ease, stroke-dashoffset 0.8s ease" }}
          />
        );
      })}
    </svg>
  );
}

// === SCREENS ===

function DashboardScreen() {
  const netWorth = accounts.reduce((s, a) => s + a.balance, 0);
  const totalSpent = categories.reduce((s, c) => s + c.spent, 0);
  const totalBudget = categories.reduce((s, c) => s + c.budget, 0);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      {/* Net Worth Card */}
      <div style={{
        background: `linear-gradient(135deg, ${COLORS.mint}18, ${COLORS.dark})`,
        borderRadius: 20, padding: "28px 24px",
        border: `1px solid ${COLORS.mint}25`,
        position: "relative", overflow: "hidden"
      }}>
        <div style={{
          position: "absolute", top: -40, right: -40, width: 160, height: 160,
          background: `radial-gradient(circle, ${COLORS.mint}12, transparent 70%)`,
          borderRadius: "50%"
        }} />
        <div style={{ fontSize: 13, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif", letterSpacing: 0.5, marginBottom: 6 }}>NET WORTH</div>
        <div style={{ fontSize: 38, fontWeight: 700, color: COLORS.textPrimary, fontFamily: "'Outfit', sans-serif", letterSpacing: -1 }}>
          ${netWorth.toLocaleString("en-US", { minimumFractionDigits: 2 })}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 8 }}>
          <span style={{ fontSize: 12, color: COLORS.mint, fontWeight: 600, fontFamily: "'DM Sans', sans-serif" }}>↑ +$1,240.50</span>
          <span style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>vs last month</span>
        </div>
      </div>

      {/* Accounts */}
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif", marginBottom: 12 }}>Accounts</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {accounts.map((acc, i) => (
            <div key={i} style={{
              background: COLORS.darkCard, borderRadius: 14, padding: "16px 14px",
              border: `1px solid ${COLORS.darkBorder}`,
              cursor: "pointer", transition: "border-color 0.2s",
            }}>
              <div style={{ fontSize: 20, marginBottom: 8 }}>{acc.icon}</div>
              <div style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif", marginBottom: 4 }}>{acc.name}</div>
              <div style={{
                fontSize: 17, fontWeight: 700, fontFamily: "'Outfit', sans-serif",
                color: acc.balance < 0 ? COLORS.red : COLORS.textPrimary
              }}>
                {acc.balance < 0 ? "-" : ""}${Math.abs(acc.balance).toLocaleString("en-US", { minimumFractionDigits: 2 })}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Monthly Overview */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 16, padding: 20,
        border: `1px solid ${COLORS.darkBorder}`
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>Income vs Spending</div>
          <div style={{ display: "flex", gap: 12, fontSize: 11, fontFamily: "'DM Sans', sans-serif" }}>
            <span style={{ display: "flex", alignItems: "center", gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: COLORS.mint }} /> <span style={{ color: COLORS.textSecondary }}>Income</span>
            </span>
            <span style={{ display: "flex", alignItems: "center", gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: COLORS.textSecondary + "50" }} /> <span style={{ color: COLORS.textSecondary }}>Spending</span>
            </span>
          </div>
        </div>
        <BarChart data={monthlyData} />
      </div>

      {/* Budget Summary */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 16, padding: 20,
        border: `1px solid ${COLORS.darkBorder}`
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>February Budget</div>
          <div style={{ fontSize: 12, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>
            ${totalSpent.toLocaleString()} / ${totalBudget.toLocaleString()}
          </div>
        </div>
        <div style={{ marginTop: 12 }}>
          <ProgressBar percent={(totalSpent / totalBudget) * 100} color={COLORS.mint} height={8} />
        </div>
        <div style={{ fontSize: 12, color: COLORS.mint, fontFamily: "'DM Sans', sans-serif", marginTop: 8 }}>
          ${(totalBudget - totalSpent).toLocaleString()} remaining
        </div>
      </div>

      {/* Recent Transactions */}
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif", marginBottom: 12 }}>Recent Transactions</div>
        {transactions.slice(0, 5).map((t, i) => (
          <div key={i} style={{
            display: "flex", alignItems: "center", padding: "14px 0",
            borderBottom: i < 4 ? `1px solid ${COLORS.darkBorder}` : "none"
          }}>
            <div style={{
              width: 40, height: 40, borderRadius: 12,
              background: COLORS.darkCard, display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 18, marginRight: 12, border: `1px solid ${COLORS.darkBorder}`
            }}>{t.icon}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>{t.name}</div>
              <div style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif", marginTop: 2 }}>{t.category} · {t.date}</div>
            </div>
            <div style={{
              fontSize: 15, fontWeight: 600, fontFamily: "'Outfit', sans-serif",
              color: t.amount > 0 ? COLORS.mint : COLORS.textPrimary
            }}>
              {t.amount > 0 ? "+" : ""}{t.amount < 0 ? "-" : ""}${Math.abs(t.amount).toFixed(2)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function BudgetsScreen() {
  const totalSpent = categories.reduce((s, c) => s + c.spent, 0);
  const totalBudget = categories.reduce((s, c) => s + c.budget, 0);
  const segments = categories.map(c => ({ value: c.spent, color: c.color }));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      {/* Donut Overview */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 20, padding: 24,
        border: `1px solid ${COLORS.darkBorder}`,
        display: "flex", flexDirection: "column", alignItems: "center"
      }}>
        <div style={{ position: "relative" }}>
          <DonutChart segments={segments} size={170} />
          <div style={{
            position: "absolute", top: "50%", left: "50%",
            transform: "translate(-50%, -50%) rotate(0deg)",
            textAlign: "center"
          }}>
            <div style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>SPENT</div>
            <div style={{ fontSize: 26, fontWeight: 700, color: COLORS.textPrimary, fontFamily: "'Outfit', sans-serif" }}>
              ${totalSpent.toLocaleString()}
            </div>
            <div style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>of ${totalBudget.toLocaleString()}</div>
          </div>
        </div>
      </div>

      {/* Category List */}
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif", marginBottom: 14 }}>Categories</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {categories.map((cat, i) => {
            const pct = (cat.spent / cat.budget) * 100;
            const over = cat.spent > cat.budget;
            return (
              <div key={i} style={{
                background: COLORS.darkCard, borderRadius: 14, padding: "16px 18px",
                border: `1px solid ${over ? COLORS.red + '40' : COLORS.darkBorder}`,
                cursor: "pointer", transition: "all 0.2s",
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <span style={{ fontSize: 20 }}>{cat.icon}</span>
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 500, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>{cat.name}</div>
                      {over && <div style={{ fontSize: 11, color: COLORS.red, fontFamily: "'DM Sans', sans-serif", marginTop: 2 }}>
                        Over by ${(cat.spent - cat.budget).toLocaleString()}
                      </div>}
                    </div>
                  </div>
                  <div style={{ textAlign: "right" }}>
                    <div style={{ fontSize: 15, fontWeight: 600, fontFamily: "'Outfit', sans-serif", color: COLORS.textPrimary }}>
                      ${cat.spent.toLocaleString()}
                    </div>
                    <div style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>
                      of ${cat.budget.toLocaleString()}
                    </div>
                  </div>
                </div>
                <ProgressBar percent={pct} color={cat.color} />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function TransactionsScreen() {
  const [searchText, setSearchText] = useState("");
  const filtered = transactions.filter(t =>
    t.name.toLowerCase().includes(searchText.toLowerCase()) ||
    t.category.toLowerCase().includes(searchText.toLowerCase())
  );
  let lastDate = "";

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Search */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 14, padding: "12px 16px",
        border: `1px solid ${COLORS.darkBorder}`,
        display: "flex", alignItems: "center", gap: 10
      }}>
        <span style={{ color: COLORS.textSecondary, fontSize: 16 }}>🔍</span>
        <input
          type="text" placeholder="Search transactions..."
          value={searchText} onChange={e => setSearchText(e.target.value)}
          style={{
            background: "none", border: "none", outline: "none", flex: 1,
            color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif", fontSize: 14
          }}
        />
      </div>

      {/* Filter Chips */}
      <div style={{ display: "flex", gap: 8, overflowX: "auto", paddingBottom: 4 }}>
        {["All", "Food", "Shopping", "Transport", "Income"].map((f, i) => (
          <div key={i} style={{
            padding: "7px 16px", borderRadius: 20, fontSize: 12,
            fontFamily: "'DM Sans', sans-serif", fontWeight: 500, cursor: "pointer",
            whiteSpace: "nowrap", transition: "all 0.2s",
            background: i === 0 ? COLORS.mint + "20" : COLORS.darkCard,
            color: i === 0 ? COLORS.mint : COLORS.textSecondary,
            border: `1px solid ${i === 0 ? COLORS.mint + "40" : COLORS.darkBorder}`
          }}>{f}</div>
        ))}
      </div>

      {/* Transaction List */}
      <div>
        {filtered.map((t, i) => {
          const showDate = t.date !== lastDate;
          lastDate = t.date;
          return (
            <div key={i}>
              {showDate && (
                <div style={{
                  fontSize: 12, fontWeight: 600, color: COLORS.textSecondary,
                  fontFamily: "'DM Sans', sans-serif", padding: "16px 0 8px",
                  letterSpacing: 0.3
                }}>{t.date}</div>
              )}
              <div style={{
                display: "flex", alignItems: "center", padding: "14px 16px",
                background: COLORS.darkCard, borderRadius: 14, marginBottom: 6,
                border: `1px solid ${COLORS.darkBorder}`, cursor: "pointer",
                transition: "border-color 0.2s"
              }}>
                <div style={{
                  width: 42, height: 42, borderRadius: 12,
                  background: COLORS.dark, display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: 20, marginRight: 14
                }}>{t.icon}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 500, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>{t.name}</div>
                  <div style={{
                    display: "inline-block", marginTop: 4, padding: "2px 8px", borderRadius: 6,
                    background: COLORS.dark, fontSize: 11, color: COLORS.textSecondary,
                    fontFamily: "'DM Sans', sans-serif"
                  }}>{t.category}</div>
                </div>
                <div style={{
                  fontSize: 16, fontWeight: 600, fontFamily: "'Outfit', sans-serif",
                  color: t.amount > 0 ? COLORS.mint : COLORS.textPrimary
                }}>
                  {t.amount > 0 ? "+" : "-"}${Math.abs(t.amount).toFixed(2)}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function TrendsScreen() {
  const spendingTrend = [3800, 4100, 4600, 5200, 3900, 3295];
  const savingsTrend = [1400, 1300, 600, 900, 1500, 1905];

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Spending Trend Card */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 16, padding: 20,
        border: `1px solid ${COLORS.darkBorder}`
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 12 }}>
          <div>
            <div style={{ fontSize: 12, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>Total Spending</div>
            <div style={{ fontSize: 28, fontWeight: 700, fontFamily: "'Outfit', sans-serif", color: COLORS.textPrimary, marginTop: 4 }}>$3,295</div>
            <div style={{ display: "flex", alignItems: "center", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 12, fontWeight: 600, color: COLORS.mint, fontFamily: "'DM Sans', sans-serif" }}>↓ 15.5%</span>
              <span style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>vs Jan</span>
            </div>
          </div>
          <MiniChart data={spendingTrend} width={100} height={45} color={COLORS.mint} />
        </div>
      </div>

      {/* Savings Trend */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 16, padding: 20,
        border: `1px solid ${COLORS.darkBorder}`
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 12 }}>
          <div>
            <div style={{ fontSize: 12, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>Net Savings</div>
            <div style={{ fontSize: 28, fontWeight: 700, fontFamily: "'Outfit', sans-serif", color: COLORS.mint, marginTop: 4 }}>$1,905</div>
            <div style={{ display: "flex", alignItems: "center", gap: 4, marginTop: 4 }}>
              <span style={{ fontSize: 12, fontWeight: 600, color: COLORS.mint, fontFamily: "'DM Sans', sans-serif" }}>↑ 27%</span>
              <span style={{ fontSize: 11, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>vs Jan</span>
            </div>
          </div>
          <MiniChart data={savingsTrend} width={100} height={45} color={COLORS.blue} />
        </div>
      </div>

      {/* Spending Insights */}
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif", marginBottom: 12 }}>Insights</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {[
            { icon: "🔥", title: "Food & Dining is over budget", desc: "You've spent $120 more than planned. Consider cooking more at home.", color: COLORS.red },
            { icon: "🎉", title: "Transportation under budget", desc: "Great job! You've saved $120 in transportation this month.", color: COLORS.mint },
            { icon: "📊", title: "Spending is trending down", desc: "Your spending decreased 15.5% compared to last month. Keep it up!", color: COLORS.blue },
          ].map((insight, i) => (
            <div key={i} style={{
              background: COLORS.darkCard, borderRadius: 14, padding: "16px 18px",
              border: `1px solid ${COLORS.darkBorder}`,
              display: "flex", gap: 14, alignItems: "flex-start"
            }}>
              <div style={{
                width: 40, height: 40, borderRadius: 12,
                background: insight.color + "15", display: "flex", alignItems: "center", justifyContent: "center",
                fontSize: 20, flexShrink: 0
              }}>{insight.icon}</div>
              <div>
                <div style={{ fontSize: 13, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>{insight.title}</div>
                <div style={{ fontSize: 12, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif", marginTop: 4, lineHeight: 1.5 }}>{insight.desc}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Top Merchants */}
      <div style={{
        background: COLORS.darkCard, borderRadius: 16, padding: 20,
        border: `1px solid ${COLORS.darkBorder}`
      }}>
        <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif", marginBottom: 14 }}>Top Merchants</div>
        {[
          { name: "Whole Foods", amount: 342, pct: 100 },
          { name: "Amazon", amount: 267, pct: 78 },
          { name: "Shell Gas", amount: 168, pct: 49 },
          { name: "Starbucks", amount: 98, pct: 29 },
        ].map((m, i) => (
          <div key={i} style={{ marginBottom: i < 3 ? 14 : 0 }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
              <span style={{ fontSize: 13, color: COLORS.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>{m.name}</span>
              <span style={{ fontSize: 13, fontWeight: 600, color: COLORS.textPrimary, fontFamily: "'Outfit', sans-serif" }}>${m.amount}</span>
            </div>
            <ProgressBar percent={m.pct} color={COLORS.mint} height={5} />
          </div>
        ))}
      </div>
    </div>
  );
}

// === MAIN APP ===

const tabs = [
  { id: "dashboard", label: "Home", icon: "⌂" },
  { id: "budgets", label: "Budgets", icon: "◎" },
  { id: "transactions", label: "Activity", icon: "↕" },
  { id: "trends", label: "Trends", icon: "◆" },
];

export default function BudgetApp() {
  const [activeTab, setActiveTab] = useState("dashboard");

  const renderScreen = () => {
    switch (activeTab) {
      case "dashboard": return <DashboardScreen />;
      case "budgets": return <BudgetsScreen />;
      case "transactions": return <TransactionsScreen />;
      case "trends": return <TrendsScreen />;
      default: return <DashboardScreen />;
    }
  };

  const screenTitle = {
    dashboard: "Overview",
    budgets: "Budgets",
    transactions: "Transactions",
    trends: "Trends",
  };

  return (
    <div style={{
      width: "100%", minHeight: "100vh",
      background: COLORS.dark,
      display: "flex", justifyContent: "center",
      fontFamily: "'DM Sans', sans-serif",
    }}>
      <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet" />

      <div style={{
        width: "100%", maxWidth: 420, minHeight: "100vh",
        position: "relative",
        background: COLORS.dark,
        borderLeft: `1px solid ${COLORS.darkBorder}`,
        borderRight: `1px solid ${COLORS.darkBorder}`,
      }}>
        {/* Status Bar */}
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "center",
          padding: "12px 24px 0",
          fontSize: 12, fontWeight: 600, color: COLORS.textPrimary,
          fontFamily: "'DM Sans', sans-serif"
        }}>
          <span>9:41</span>
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <span style={{ fontSize: 10 }}>📶</span>
            <span style={{ fontSize: 10 }}>📡</span>
            <span style={{ fontSize: 10 }}>🔋</span>
          </div>
        </div>

        {/* Header */}
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "center",
          padding: "18px 24px 12px"
        }}>
          <div>
            <div style={{ fontSize: 12, color: COLORS.textSecondary, fontFamily: "'DM Sans', sans-serif" }}>February 2026</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: COLORS.textPrimary, fontFamily: "'Outfit', sans-serif", letterSpacing: -0.5, marginTop: 2 }}>
              {screenTitle[activeTab]}
            </div>
          </div>
          <div style={{
            width: 40, height: 40, borderRadius: "50%",
            background: `linear-gradient(135deg, ${COLORS.mint}, ${COLORS.mintDark})`,
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 16, fontWeight: 700, color: COLORS.dark,
            fontFamily: "'Outfit', sans-serif", cursor: "pointer",
            boxShadow: `0 4px 16px ${COLORS.mint}30`
          }}>JD</div>
        </div>

        {/* Content */}
        <div style={{
          padding: "0 20px 100px",
          overflowY: "auto",
        }}>
          {renderScreen()}
        </div>

        {/* Bottom Tab Bar */}
        <div style={{
          position: "fixed", bottom: 0,
          width: "100%", maxWidth: 420,
          background: `${COLORS.dark}F0`,
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          borderTop: `1px solid ${COLORS.darkBorder}`,
          display: "flex", justifyContent: "space-around",
          padding: "10px 0 28px",
          zIndex: 100
        }}>
          {tabs.map(tab => {
            const active = activeTab === tab.id;
            return (
              <div key={tab.id} onClick={() => setActiveTab(tab.id)}
                style={{
                  display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
                  cursor: "pointer", padding: "4px 16px",
                  transition: "all 0.2s"
                }}>
                <span style={{
                  fontSize: 20,
                  color: active ? COLORS.mint : COLORS.textSecondary,
                  filter: active ? `drop-shadow(0 0 6px ${COLORS.mint}60)` : "none",
                  transition: "all 0.3s"
                }}>{tab.icon}</span>
                <span style={{
                  fontSize: 10, fontWeight: active ? 600 : 400,
                  color: active ? COLORS.mint : COLORS.textSecondary,
                  fontFamily: "'DM Sans', sans-serif",
                  transition: "color 0.2s"
                }}>{tab.label}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}