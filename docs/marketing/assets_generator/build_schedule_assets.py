# Build Schedule Assets
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCREENSHOTS_HTML_PATH = os.path.join(BASE_DIR, "screenshots.html")
VIDEO_HTML_PATH = os.path.join(BASE_DIR, "video_trailer_16_9.html")

def generate_screenshots_html():
    content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ROCIs Schedule - Play Store Screenshots</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-font-smoothing: antialiased; }
    body { font-family: 'Outfit', sans-serif; background: #060709; color: #ffffff; display: flex; flex-direction: column; align-items: center; }

    /* 9:16 Canvas Standard: 1080 x 1920 */
    .slide-canvas {
      width: 1080px;
      height: 1920px;
      position: relative;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 60px;
      background-color: #0c0d12;
    }

    /* Ambient Gradients */
    .bg-mesh-blue {
      position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 6%, rgba(30, 136, 229, 0.38) 0%, transparent 55%),
                  radial-gradient(circle at 85% 65%, rgba(99, 102, 241, 0.22) 0%, transparent 50%),
                  radial-gradient(circle at 15% 80%, rgba(16, 185, 129, 0.16) 0%, transparent 50%),
                  linear-gradient(180deg, #101622 0%, #07090E 100%);
    }
    .bg-mesh-emerald {
      position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 6%, rgba(16, 185, 129, 0.36) 0%, transparent 55%),
                  radial-gradient(circle at 85% 65%, rgba(6, 182, 212, 0.22) 0%, transparent 50%),
                  linear-gradient(180deg, #0A1916 0%, #060D0B 100%);
    }
    .bg-mesh-crimson {
      position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 6%, rgba(239, 68, 68, 0.38) 0%, transparent 55%),
                  radial-gradient(circle at 85% 70%, rgba(245, 158, 11, 0.20) 0%, transparent 50%),
                  linear-gradient(180deg, #1A0E11 0%, #0B0608 100%);
    }
    .bg-mesh-purple {
      position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 6%, rgba(139, 92, 246, 0.36) 0%, transparent 55%),
                  radial-gradient(circle at 15% 75%, rgba(236, 72, 153, 0.20) 0%, transparent 50%),
                  linear-gradient(180deg, #171124 0%, #0A0712 100%);
    }
    .bg-mesh-amoled {
      position: absolute; inset: 0;
      background: radial-gradient(circle at 50% 8%, rgba(30, 136, 229, 0.28) 0%, transparent 50%),
                  radial-gradient(circle at 50% 85%, rgba(16, 185, 129, 0.16) 0%, transparent 50%),
                  linear-gradient(180deg, #07090E 0%, #000000 100%);
    }

    .grid-lines {
      position: absolute; inset: 0;
      background-size: 60px 60px;
      background-image: linear-gradient(to right, rgba(255,255,255,0.025) 1px, transparent 1px),
                        linear-gradient(to bottom, rgba(255,255,255,0.025) 1px, transparent 1px);
      pointer-events: none;
    }

    /* Header text container */
    .header-box {
      width: 100%;
      text-align: center;
      padding: 50px 48px 10px 48px;
      z-index: 15;
    }
    .tag-badge {
      display: inline-flex; align-items: center; gap: 10px;
      padding: 8px 24px; border-radius: 9999px;
      font-size: 17px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase;
      margin-bottom: 12px; backdrop-filter: blur(16px);
    }
    .badge-blue { background: rgba(30, 136, 229, 0.18); color: #60A5FA; border: 1.5px solid rgba(30, 136, 229, 0.45); }
    .badge-emerald { background: rgba(16, 185, 129, 0.18); color: #34D399; border: 1.5px solid rgba(16, 185, 129, 0.45); }
    .badge-crimson { background: rgba(239, 68, 68, 0.18); color: #F87171; border: 1.5px solid rgba(239, 68, 68, 0.45); }
    .badge-purple { background: rgba(139, 92, 246, 0.18); color: #C084FC; border: 1.5px solid rgba(139, 92, 246, 0.45); }

    .title-text {
      font-size: 58px; font-weight: 900; line-height: 1.12; letter-spacing: -0.025em; margin-bottom: 10px; color: #FFFFFF;
    }
    .desc-text {
      font-size: 23px; font-weight: 500; line-height: 1.35; max-width: 880px; margin: 0 auto 12px auto; color: #94A3B8;
    }

    .highlight-blue {
      background: linear-gradient(135deg, #93C5FD 0%, #3B82F6 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .highlight-emerald {
      background: linear-gradient(135deg, #6EE7B7 0%, #10B981 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .highlight-crimson {
      background: linear-gradient(135deg, #FCA5A5 0%, #EF4444 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .highlight-purple {
      background: linear-gradient(135deg, #D8B4FE 0%, #8B5CF6 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }

    /* Device Mockup Shell */
    .device-wrap {
      position: absolute; top: 310px; bottom: -50px; width: 900px;
      border-radius: 64px 64px 0 0; padding: 14px 14px 0 14px;
      z-index: 10; display: flex; flex-direction: column;
      background: #131722; border: 3.5px solid #2B3346; border-bottom: none;
      box-shadow: 0 -20px 80px rgba(0,0,0,0.85), 0 0 60px rgba(30, 136, 229, 0.2);
    }
    .device-screen-box {
      width: 100%; height: 100%; flex: 1; border-radius: 50px 50px 0 0;
      overflow: hidden; position: relative; display: flex; flex-direction: column;
      background: #0D111A; color: #FFFFFF; font-family: 'Inter', sans-serif;
    }

    /* Phone Status Bar */
    .phone-status-bar {
      height: 52px; display: flex; justify-content: space-between; align-items: center;
      padding: 0 36px; font-size: 18px; font-weight: 700; z-index: 20; color: #94A3B8;
    }
    .notch-camera {
      width: 15px; height: 15px; background: #000000; border-radius: 50%;
      border: 1.5px solid rgba(255,255,255,0.2);
    }

    /* App UI Components */
    .app-header-nav {
      display: flex; justify-content: space-between; align-items: center;
      padding: 12px 32px 18px 32px; border-bottom: 1px solid rgba(255,255,255,0.06);
    }
    .app-brand { display: flex; align-items: center; gap: 14px; }
    .app-logo-sq {
      width: 46px; height: 46px; border-radius: 14px;
      background: linear-gradient(135deg, #1E88E5 0%, #1565C0 100%);
      display: flex; align-items: center; justify-content: center; font-size: 24px;
      box-shadow: 0 4px 16px rgba(30, 136, 229, 0.4);
    }
    .app-title-h1 { font-size: 25px; font-weight: 800; font-family: 'Outfit', sans-serif; }
    .header-icons { display: flex; gap: 16px; font-size: 22px; color: #CBD5E1; }

    /* Day Strip */
    .day-strip {
      display: flex; gap: 12px; padding: 18px 32px; overflow-x: auto;
    }
    .day-pill {
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      width: 72px; height: 86px; border-radius: 20px;
      background: rgba(255,255,255,0.04); border: 1.5px solid rgba(255,255,255,0.08);
      font-weight: 700; font-size: 16px; color: #94A3B8;
    }
    .day-pill.active {
      background: linear-gradient(135deg, #1E88E5 0%, #1976D2 100%);
      border-color: #64B5F6; color: #FFFFFF;
      box-shadow: 0 8px 24px rgba(30, 136, 229, 0.4);
    }
    .day-pill .day-num { font-size: 26px; font-weight: 900; margin-top: 4px; font-family: 'Outfit', sans-serif; }

    /* Glass Cards */
    .glass-card {
      margin: 10px 32px; padding: 22px 26px; border-radius: 24px;
      background: rgba(255,255,255,0.04); border: 1.5px solid rgba(255,255,255,0.09);
      backdrop-filter: blur(20px); position: relative;
    }
    .glass-card-exam {
      background: linear-gradient(135deg, rgba(239, 68, 68, 0.15) 0%, rgba(220, 38, 38, 0.05) 100%);
      border: 1.5px solid rgba(239, 68, 68, 0.35);
      box-shadow: 0 10px 30px rgba(239, 68, 68, 0.15);
    }
    .glass-card-gpa {
      background: linear-gradient(135deg, rgba(16, 185, 129, 0.15) 0%, rgba(5, 150, 105, 0.05) 100%);
      border: 1.5px solid rgba(16, 185, 129, 0.35);
      box-shadow: 0 10px 30px rgba(16, 185, 129, 0.15);
    }

    .event-color-strip {
      position: absolute; left: 0; top: 0; bottom: 0; width: 8px; border-radius: 24px 0 0 24px;
    }
    .event-time-badge {
      display: inline-flex; align-items: center; gap: 6px;
      padding: 5px 14px; border-radius: 9999px;
      font-size: 14px; font-weight: 700; background: rgba(255,255,255,0.08); color: #CBD5E1;
      margin-bottom: 10px;
    }
    .event-title { font-size: 24px; font-weight: 800; margin-bottom: 6px; }
    .event-subtitle { font-size: 16px; color: #94A3B8; display: flex; align-items: center; gap: 16px; }

    /* Floating Badge on screenshot */
    .glass-badge-floating {
      position: absolute; z-index: 35;
      padding: 14px 26px; border-radius: 20px;
      font-size: 20px; font-weight: 800; display: flex; align-items: center; gap: 12px;
      box-shadow: 0 20px 45px rgba(0,0,0,0.7);
      border: 1.5px solid rgba(255,255,255,0.22);
      backdrop-filter: blur(25px);
    }

    /* Bottom Navigation Bar */
    .bottom-nav {
      position: absolute; bottom: 0; left: 0; right: 0; height: 92px;
      background: rgba(13, 17, 26, 0.95); border-top: 1px solid rgba(255,255,255,0.08);
      display: flex; justify-content: space-around; align-items: center;
      padding: 0 20px 10px 20px; z-index: 25; backdrop-filter: blur(20px);
    }
    .nav-item { display: flex; flex-direction: column; align-items: center; gap: 5px; color: #64748B; font-size: 13px; font-weight: 600; }
    .nav-item.active { color: #60A5FA; }
    .nav-item-icon { font-size: 26px; }

    /* Feature Graphic (1024 x 500) */
    .fg-canvas {
      width: 1024px; height: 500px; position: relative; overflow: hidden;
      display: flex; align-items: center; padding: 0 60px;
      background: #090C13; margin-bottom: 60px;
      border: 2px solid rgba(255,255,255,0.1);
    }
    .fg-bg-mesh {
      position: absolute; inset: 0;
      background: radial-gradient(circle at 25% 40%, rgba(30, 136, 229, 0.40) 0%, transparent 60%),
                  radial-gradient(circle at 75% 60%, rgba(16, 185, 129, 0.25) 0%, transparent 55%),
                  linear-gradient(135deg, #101624 0%, #06080E 100%);
    }
    .fg-content { position: relative; z-index: 10; max-width: 580px; }
    .fg-brand { display: flex; align-items: center; gap: 16px; margin-bottom: 16px; }
    .fg-logo {
      width: 56px; height: 56px; border-radius: 16px;
      background: linear-gradient(135deg, #1E88E5 0%, #1565C0 100%);
      display: flex; align-items: center; justify-content: center; font-size: 30px;
      box-shadow: 0 8px 24px rgba(30, 136, 229, 0.5);
    }
    .fg-appname { font-size: 38px; font-weight: 900; letter-spacing: -0.02em; font-family: 'Outfit', sans-serif; }
    .fg-headline { font-size: 42px; font-weight: 900; line-height: 1.15; margin-bottom: 20px; }
    .fg-pills { display: flex; flex-wrap: wrap; gap: 10px; }
    .fg-pill {
      padding: 8px 18px; border-radius: 9999px;
      background: rgba(255,255,255,0.08); border: 1.5px solid rgba(255,255,255,0.15);
      font-size: 15px; font-weight: 700; backdrop-filter: blur(10px);
    }
    .fg-mockup {
      position: absolute; right: 40px; top: 35px; width: 340px; height: 600px;
      border-radius: 42px 42px 0 0; padding: 10px 10px 0 10px;
      background: #141926; border: 3px solid #2B3348;
      box-shadow: -20px 20px 60px rgba(0,0,0,0.8), 0 0 50px rgba(30, 136, 229, 0.3);
      transform: rotate(-5deg) translateY(20px);
    }
    .fg-mockup-inner {
      width: 100%; height: 100%; border-radius: 34px 34px 0 0;
      background: #0E121C; padding: 18px; font-family: 'Inter', sans-serif;
    }
  </style>
</head>
<body>

  <!-- SLIDE 1: Weekly Timetable -->
  <div class="slide-canvas" id="slide-1">
    <div class="bg-mesh-blue"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-blue" id="s1-tag">📚 ACADEMIC TIMETABLE PLANNER</div>
      <h1 class="title-text" id="s1-title">Master Your Semester. <span class="highlight-blue">Effortlessly.</span></h1>
      <p class="desc-text" id="s1-desc">Intuitive weekly class schedule, glassmorphic UI, and quick day-strip navigation.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(30, 136, 229, 0.25); color: #93C5FD;">
      ⚡ Weekly Class Timetable
    </div>
    <div class="device-wrap">
      <div class="device-screen-box">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq">📅</div>
            <div>
              <div class="app-title-h1">ROCIs Schedule</div>
              <div style="font-size: 13px; color: #94A3B8;">Semester A • 2026</div>
            </div>
          </div>
          <div class="header-icons"><span>🔔</span><span>⚙️</span></div>
        </div>
        <div class="day-strip">
          <div class="day-pill"><span style="font-size: 13px;">SUN</span><span class="day-num">03</span></div>
          <div class="day-pill active"><span style="font-size: 13px;">MON</span><span class="day-num">04</span></div>
          <div class="day-pill"><span style="font-size: 13px;">TUE</span><span class="day-num">05</span></div>
          <div class="day-pill"><span style="font-size: 13px;">WED</span><span class="day-num">06</span></div>
          <div class="day-pill"><span style="font-size: 13px;">THU</span><span class="day-num">07</span></div>
          <div class="day-pill"><span style="font-size: 13px;">FRI</span><span class="day-num">08</span></div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #2196F3;"></div>
          <div class="event-time-badge">⏰ 10:00 - 12:00 • CS301</div>
          <div class="event-title">Data Structures & Algorithms</div>
          <div class="event-subtitle">
            <span>📍 Turing Hall 101</span>
            <span>👨‍🏫 Prof. Alan Turing</span>
          </div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #9C27B0;"></div>
          <div class="event-time-badge">⏰ 13:00 - 15:00 • MATH201</div>
          <div class="event-title">Linear Algebra & Matrices</div>
          <div class="event-subtitle">
            <span>📍 Euler Auditorium B</span>
            <span>👩‍🏫 Dr. Emmy Noether</span>
          </div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #4CAF50;"></div>
          <div class="event-time-badge">⏰ 16:00 - 18:00 • CS405</div>
          <div class="event-title">Machine Learning Lab</div>
          <div class="event-subtitle">
            <span>📍 Silicon Lab 304</span>
            <span>👨‍🏫 Dr. Geoffrey Hinton</span>
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item active"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 2: GPA & Credits -->
  <div class="slide-canvas" id="slide-2">
    <div class="bg-mesh-emerald"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-emerald" id="s2-tag">🎓 GPA & CREDIT CALCULATOR</div>
      <h1 class="title-text" id="s2-title">Track Your Grades. <span class="highlight-emerald">Know Your Standing.</span></h1>
      <p class="desc-text" id="s2-desc">Real-time 4.0 GPA scale converter and semester credit weight calculations.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(16, 185, 129, 0.25); color: #6EE7B7;">
      ⚡ Live 4.0 GPA Converter
    </div>
    <div class="device-wrap">
      <div class="device-screen-box">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq" style="background: linear-gradient(135deg, #10B981 0%, #059669 100%);">🎓</div>
            <div>
              <div class="app-title-h1">Academic Overview</div>
              <div style="font-size: 13px; color: #94A3B8;">Degree Progress Tracker</div>
            </div>
          </div>
          <div class="header-icons"><span>➕</span></div>
        </div>
        <div class="glass-card glass-card-gpa" style="display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-size: 14px; font-weight: 700; color: #34D399; text-transform: uppercase;">Cumulative GPA</div>
            <div style="font-size: 48px; font-weight: 900; font-family: 'Outfit'; color: #FFFFFF;">3.88 <span style="font-size: 22px; color: #94A3B8;">/ 4.0</span></div>
            <div style="font-size: 15px; color: #CBD5E1;">Average: <strong>93.6%</strong> • Total: <strong>22.0 Credits</strong></div>
          </div>
          <div style="width: 80px; height: 80px; border-radius: 50%; border: 6px solid #10B981; display: flex; align-items: center; justify-content: center; font-size: 26px; font-weight: 900;">A</div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #2196F3;"></div>
          <div style="display: flex; justify-content: space-between;">
            <div>
              <div class="event-title">Operating Systems</div>
              <div class="event-subtitle">CS302 • 4.0 Credits</div>
            </div>
            <div style="text-align: right;">
              <div style="font-size: 26px; font-weight: 900; color: #34D399;">96</div>
              <div style="font-size: 13px; color: #94A3B8;">GPA 4.0</div>
            </div>
          </div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #9C27B0;"></div>
          <div style="display: flex; justify-content: space-between;">
            <div>
              <div class="event-title">Distributed Databases</div>
              <div class="event-subtitle">CS410 • 3.5 Credits</div>
            </div>
            <div style="text-align: right;">
              <div style="font-size: 26px; font-weight: 900; color: #34D399;">92</div>
              <div style="font-size: 13px; color: #94A3B8;">GPA 3.7</div>
            </div>
          </div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #FF9800;"></div>
          <div style="display: flex; justify-content: space-between;">
            <div>
              <div class="event-title">Computer Networks</div>
              <div class="event-subtitle">CS315 • 3.0 Credits</div>
            </div>
            <div style="text-align: right;">
              <div style="font-size: 26px; font-weight: 900; color: #34D399;">94</div>
              <div style="font-size: 13px; color: #94A3B8;">GPA 4.0</div>
            </div>
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item active"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 3: Live Exam Countdown -->
  <div class="slide-canvas" id="slide-3">
    <div class="bg-mesh-crimson"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-crimson" id="s3-tag">🚨 LIVE EXAM COUNTDOWN</div>
      <h1 class="title-text" id="s3-title">Never Miss an Exam. <span class="highlight-crimson">Stay Test-Ready.</span></h1>
      <p class="desc-text" id="s3-desc">Pinned countdown banner highlights upcoming midterms and finals with real-time badges.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(239, 68, 68, 0.25); color: #FCA5A5;">
      ⏳ Live Countdown Alerts
    </div>
    <div class="device-wrap">
      <div class="device-screen-box">
        <div class="phone-status-bar"><span>09:41</span><div class=\"notch-camera\"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq" style="background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%);">🚨</div>
            <div>
              <div class="app-title-h1">Upcoming Exams</div>
              <div style="font-size: 13px; color: #94A3B8;">Exam Season Mode</div>
            </div>
          </div>
        </div>
        <div class="glass-card glass-card-exam">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
            <span style="background: #EF4444; color: #FFF; padding: 4px 12px; border-radius: 9999px; font-weight: 800; font-size: 13px;">FINAL EXAM</span>
            <span style="font-weight: 900; color: #F87171; font-size: 16px;">⏳ In 3 Days</span>
          </div>
          <div class="event-title">Data Structures & Algorithms</div>
          <div class="event-subtitle" style="margin-top: 8px;">
            <span>📅 Thu, Sep 07 • 09:00</span>
            <span>📍 Building A - Hall 201</span>
          </div>
        </div>
        <div class="glass-card glass-card-exam" style="border-color: rgba(245, 158, 11, 0.4); background: linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, transparent 100%);">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
            <span style="background: #F59E0B; color: #FFF; padding: 4px 12px; border-radius: 9999px; font-weight: 800; font-size: 13px;">MIDTERM</span>
            <span style="font-weight: 900; color: #FBBF24; font-size: 16px;">⏳ In 9 Days</span>
          </div>
          <div class="event-title">Probability & Statistics</div>
          <div class="event-subtitle" style="margin-top: 8px;">
            <span>📅 Wed, Sep 13 • 14:30</span>
            <span>📍 Math Wing - Room 104</span>
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item active"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 4: Assignments & Deadlines -->
  <div class="slide-canvas" id="slide-4">
    <div class="bg-mesh-purple"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-purple" id="s4-tag">📝 ASSIGNMENTS & TASKS</div>
      <h1 class="title-text" id="s4-title">Conquer Deadlines. <span class="highlight-purple">Prioritize Smartly.</span></h1>
      <p class="desc-text" id="s4-desc">Track homework, lab reports, and projects with priority pills and instant checkboxes.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(139, 92, 246, 0.25); color: #C084FC;">
      ⚡ Smart Due Date Sorting
    </div>
    <div class="device-wrap">
      <div class="device-screen-box">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq" style="background: linear-gradient(135deg, #8B5CF6 0%, #6D28D9 100%);">📝</div>
            <div>
              <div class="app-title-h1">Assignments</div>
              <div style="font-size: 13px; color: #94A3B8;">5 Pending • 2 Due Today</div>
            </div>
          </div>
          <div class="header-icons"><span>➕</span></div>
        </div>
        <div class="glass-card" style="display: flex; align-items: center; gap: 16px;">
          <div style="width: 28px; height: 28px; border-radius: 8px; border: 2px solid #EF4444;"></div>
          <div style="flex: 1;">
            <div style="display: flex; gap: 8px; margin-bottom: 6px;">
              <span style="background: rgba(239, 68, 68, 0.2); color: #F87171; padding: 2px 10px; border-radius: 9999px; font-size: 12px; font-weight: 800;">HIGH</span>
              <span style="color: #94A3B8; font-size: 13px;">CS301</span>
            </div>
            <div class="event-title" style="font-size: 21px;">Homework 4: Red-Black Trees</div>
            <div class="event-subtitle">📅 Due Tomorrow at 23:59</div>
          </div>
        </div>
        <div class="glass-card" style="display: flex; align-items: center; gap: 16px;">
          <div style="width: 28px; height: 28px; border-radius: 8px; border: 2px solid #F59E0B;"></div>
          <div style="flex: 1;">
            <div style="display: flex; gap: 8px; margin-bottom: 6px;">
              <span style="background: rgba(245, 158, 11, 0.2); color: #FBBF24; padding: 2px 10px; border-radius: 9999px; font-size: 12px; font-weight: 800;">MEDIUM</span>
              <span style="color: #94A3B8; font-size: 13px;">MATH201</span>
            </div>
            <div class="event-title" style="font-size: 21px;">Problem Set 6: Eigenvalues</div>
            <div class="event-subtitle">📅 Due in 3 days</div>
          </div>
        </div>
        <div class="glass-card" style="display: flex; align-items: center; gap: 16px; opacity: 0.6;">
          <div style="width: 28px; height: 28px; border-radius: 8px; background: #10B981; display: flex; align-items: center; justify-content: center; font-size: 18px;">✓</div>
          <div style="flex: 1;">
            <div class="event-title" style="font-size: 21px; text-decoration: line-through;">CS405 Lab 2 Submission</div>
            <div class="event-subtitle">Completed yesterday</div>
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item active"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 5: 1-Click ICS Import -->
  <div class="slide-canvas" id="slide-5">
    <div class="bg-mesh-blue"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-blue" id="s5-tag">📥 1-CLICK CALENDAR IMPORT</div>
      <h1 class="title-text" id="s5-title">Import Your Timetable <span class="highlight-blue">in Seconds.</span></h1>
      <p class="desc-text" id="s5-desc">Seamlessly load .ics schedule files exported from Canvas, Moodle, Blackboard, or Google Calendar.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(30, 136, 229, 0.25); color: #93C5FD;">
      ⚡ Moodle & Canvas Ready
    </div>
    <div class="device-wrap">
      <div class="device-screen-box">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq">📥</div>
            <div>
              <div class="app-title-h1">Import Timetable</div>
              <div style="font-size: 13px; color: #94A3B8;">Universal .ICS Parser</div>
            </div>
          </div>
        </div>
        <div class="glass-card" style="text-align: center; padding: 36px 24px; border: 2px dashed rgba(30, 136, 229, 0.4);">
          <div style="font-size: 52px; margin-bottom: 12px;">📄</div>
          <div style="font-size: 22px; font-weight: 800; margin-bottom: 6px;">semester_timetable_2026.ics</div>
          <div style="font-size: 15px; color: #94A3B8; margin-bottom: 20px;">Successfully parsed 6 courses & 18 recurring lectures</div>
          <div style="display: inline-block; padding: 14px 34px; border-radius: 9999px; background: linear-gradient(135deg, #1E88E5 0%, #1565C0 100%); font-weight: 800; font-size: 17px; box-shadow: 0 8px 24px rgba(30, 136, 229, 0.4);">
            Confirm & Import All (1-Tap)
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item active"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 6: ROCIs Ecosystem Synergy -->
  <div class="slide-canvas" id="slide-6">
    <div class="bg-mesh-crimson"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-crimson" id="s6-tag">🔗 UNIFIED PRODUCTIVITY ECOSYSTEM</div>
      <h1 class="title-text" id="s6-title">ROCIs Schedule <span class="highlight-crimson">+ ROCIs Tasks.</span></h1>
      <p class="desc-text" id="s6-desc">Send course assignments straight into ROCIs Tasks with one tap for unified productivity.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(239, 68, 68, 0.25); color: #FCA5A5;">
      ⚡ Cross-App Integration
    </div>
    <div class="device-wrap">
      <div class="device-screen-box">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div style="padding: 30px; text-align: center;">
          <div style="display: flex; justify-content: center; align-items: center; gap: 24px; margin-bottom: 24px;">
            <div class="app-logo-sq" style="width: 72px; height: 72px; font-size: 38px;">📅</div>
            <div style="font-size: 32px; font-weight: 900; color: #94A3B8;">⟷</div>
            <div class="app-logo-sq" style="width: 72px; height: 72px; font-size: 38px; background: linear-gradient(135deg, #EF4444 0%, #B91C1C 100%);">⚡</div>
          </div>
          <div style="font-size: 26px; font-weight: 800; margin-bottom: 12px;">Unified Student Workflow</div>
          <p style="font-size: 16px; color: #94A3B8; max-width: 500px; margin: 0 auto 24px auto;">
            Keep your class schedule synchronized with your personal task board and daily habit tracker.
          </p>
          <div class="glass-card" style="text-align: left;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <div>
                <div style="font-size: 18px; font-weight: 800;">Export Assignment to ROCIs Tasks</div>
                <div style="font-size: 14px; color: #94A3B8;">Instant deep link with due date & priority</div>
              </div>
              <span style="font-size: 24px;">🚀</span>
            </div>
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item active"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 7: Multilingual & RTL -->
  <div class="slide-canvas" id="slide-7">
    <div class="bg-mesh-emerald"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-emerald" id="s7-tag">🌍 8 GLOBAL LANGUAGES & RTL</div>
      <h1 class="title-text" id="s7-title">Built for Students <span class="highlight-emerald">Everywhere.</span></h1>
      <p class="desc-text" id="s7-desc">Native English, Hebrew (עברית), Spanish, German, French, Arabic, Hindi, and Swedish support.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(16, 185, 129, 0.25); color: #6EE7B7;">
      🌐 Complete RTL Support
    </div>
    <div class="device-wrap">
      <div class="device-screen-box" style="direction: rtl;">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq" style="background: linear-gradient(135deg, #10B981 0%, #059669 100%);">📅</div>
            <div>
              <div class="app-title-h1">מערכת שעות</div>
              <div style="font-size: 13px; color: #94A3B8;">סמסטר א' • תשפ"ו</div>
            </div>
          </div>
          <div class="header-icons"><span>🔔</span><span>⚙️</span></div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #2196F3; right: 0; left: auto; border-radius: 0 24px 24px 0;"></div>
          <div class="event-time-badge">⏰ 10:00 - 12:00 • מדמ"ח</div>
          <div class="event-title">מבני נתונים ואלגוריתמים</div>
          <div class="event-subtitle">
            <span>📍 אולם טורינג 101</span>
            <span>👨‍🏫 פרופ' אלן טורינג</span>
          </div>
        </div>
        <div class="glass-card">
          <div class="event-color-strip" style="background: #9C27B0; right: 0; left: auto; border-radius: 0 24px 24px 0;"></div>
          <div class="event-time-badge">⏰ 13:00 - 15:00 • מתמטיקה</div>
          <div class="event-title">אלגברה לינארית ומטריצות</div>
          <div class="event-subtitle">
            <span>📍 בניין אוילר - אולם ב'</span>
            <span>👩‍🏫 ד"ר אמי נתר</span>
          </div>
        </div>
        <div class="bottom-nav" style="direction: ltr;">
          <div class="nav-item active"><span class="nav-item-icon">📅</span><span>מערכת</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>קורסים</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>מטלות</span></div>
          <div class="nav-item"><span class="nav-item-icon">👤</span><span>פרופיל</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- SLIDE 8: AMOLED Dark Mode -->
  <div class="slide-canvas" id="slide-8">
    <div class="bg-mesh-amoled"></div>
    <div class="grid-lines"></div>
    <div class="header-box">
      <div class="tag-badge badge-blue" id="s8-tag">🎨 MATERIAL YOU & GLASSMORPHISM</div>
      <h1 class="title-text" id="s8-title">Stunning Glassmorphism. <span class="highlight-blue">Pure AMOLED.</span></h1>
      <p class="desc-text" id="s8-desc">Battery-saving true black AMOLED theme, Gaussian backdrop blurs, and dynamic palette accents.</p>
    </div>
    <div class="glass-badge-floating" style="top: 255px; right: 110px; background: rgba(30, 136, 229, 0.25); color: #93C5FD;">
      ✨ Pure AMOLED Black
    </div>
    <div class="device-wrap" style="background: #050507; border-color: #1A1F2C;">
      <div class="device-screen-box" style="background: #000000;">
        <div class="phone-status-bar"><span>09:41</span><div class="notch-camera"></div><span>100% 🔋</span></div>
        <div class="app-header-nav">
          <div class="app-brand">
            <div class="app-logo-sq">✨</div>
            <div>
              <div class="app-title-h1">Settings & Themes</div>
              <div style="font-size: 13px; color: #94A3B8;">Customization Suite</div>
            </div>
          </div>
        </div>
        <div class="glass-card" style="background: rgba(255,255,255,0.03); border-color: rgba(255,255,255,0.06); display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-size: 20px; font-weight: 800;">AMOLED Dark Mode</div>
            <div style="font-size: 14px; color: #94A3B8;">True deep pitch black pixels</div>
          </div>
          <div style="width: 52px; height: 30px; border-radius: 9999px; background: #1E88E5; display: flex; align-items: center; justify-content: flex-end; padding: 3px;">
            <div style="width: 24px; height: 24px; border-radius: 50%; background: #FFF;"></div>
          </div>
        </div>
        <div class="glass-card" style="background: rgba(255,255,255,0.03); border-color: rgba(255,255,255,0.06); display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-size: 20px; font-weight: 800;">Glassmorphism Effects</div>
            <div style="font-size: 14px; color: #94A3B8;">Gaussian blur & frosted cards</div>
          </div>
          <div style="width: 52px; height: 30px; border-radius: 9999px; background: #1E88E5; display: flex; align-items: center; justify-content: flex-end; padding: 3px;">
            <div style="width: 24px; height: 24px; border-radius: 50%; background: #FFF;"></div>
          </div>
        </div>
        <div class="bottom-nav">
          <div class="nav-item"><span class="nav-item-icon">📅</span><span>Schedule</span></div>
          <div class="nav-item"><span class="nav-item-icon">📚</span><span>Courses</span></div>
          <div class="nav-item"><span class="nav-item-icon">📝</span><span>Assignments</span></div>
          <div class="nav-item active"><span class="nav-item-icon">👤</span><span>Profile</span></div>
        </div>
      </div>
    </div>
  </div>

  <!-- FEATURE GRAPHIC: 1024 x 500 -->
  <div class="fg-canvas" id="feature-graphic">
    <div class="fg-bg-mesh"></div>
    <div class="grid-lines"></div>
    <div class="fg-content">
      <div class="fg-brand">
        <div class="fg-logo">📅</div>
        <div class="fg-appname">ROCIs Schedule</div>
      </div>
      <h1 class="fg-headline" id="fg-headline">Master Your Semester. <span class="highlight-blue">Effortlessly.</span></h1>
      <div class="fg-pills">
        <div class="fg-pill" id="fg-pill1">📅 Weekly Timetable</div>
        <div class="fg-pill" id="fg-pill2">🎓 GPA Calculator</div>
        <div class="fg-pill" id="fg-pill3">🚨 Exam Countdown</div>
        <div class="fg-pill" id="fg-pill4">📥 .ICS Importer</div>
      </div>
    </div>
    <div class="fg-mockup">
      <div class="fg-mockup-inner">
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 12px;">
          <div style="width: 10px; height: 10px; border-radius: 50%; background: #1E88E5;"></div>
          <div style="font-size: 13px; font-weight: 800;">Algorithms & Data Structures</div>
        </div>
        <div style="font-size: 11px; color: #94A3B8; margin-bottom: 12px;">10:00 - 12:00 • Turing Hall 101</div>
        <div style="padding: 10px; border-radius: 12px; background: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.3);">
          <div style="font-size: 11px; color: #34D399; font-weight: 700;">GPA: 3.88 / 4.0 (A)</div>
        </div>
      </div>
    </div>
  </div>

  <script>
    async function applyLanguage(lang) {
      try {
        const resp = await fetch('locales.json');
        const locales = await resp.json();
        const data = locales[lang] || locales['en'];
        
        for (let i = 1; i <= 8; i++) {
          const s = data['slide' + i];
          if (s) {
            const tagEl = document.getElementById('s' + i + '-tag');
            const titleEl = document.getElementById('s' + i + '-title');
            const descEl = document.getElementById('s' + i + '-desc');
            if (tagEl) tagEl.innerHTML = s.tag;
            if (titleEl) titleEl.innerHTML = s.title;
            if (descEl) descEl.innerHTML = s.subtitle;
          }
        }

        const fg = data['featureGraphic'];
        if (fg) {
          const fgHead = document.getElementById('fg-headline');
          const p1 = document.getElementById('fg-pill1');
          const p2 = document.getElementById('fg-pill2');
          const p3 = document.getElementById('fg-pill3');
          const p4 = document.getElementById('fg-pill4');
          if (fgHead) fgHead.innerHTML = fg.tagline;
          if (p1) p1.innerHTML = fg.badge1;
          if (p2) p2.innerHTML = fg.badge2;
          if (p3) p3.innerHTML = fg.badge3;
          if (p4) p4.innerHTML = fg.badge4;
        }
      } catch (err) {
        console.error('Error applying language:', err);
      }
    }

    const urlParams = new URLSearchParams(window.location.search);
    const lang = urlParams.get('lang') || 'en';
    applyLanguage(lang);
  </script>
</body>
</html>
"""
    with open(SCREENSHOTS_HTML_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print("Generated screenshots.html successfully.")

def generate_video_html():
    content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ROCIs Schedule - 16:9 Promo Trailer</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@600;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-font-smoothing: antialiased; }
    body {
      background: #000; color: #fff; font-family: 'Outfit', sans-serif;
      overflow: hidden; display: flex; justify-content: center; align-items: center;
      width: 1920px; height: 1080px;
    }
    #stage {
      width: 1920px; height: 1080px; position: relative;
      background: radial-gradient(circle at 50% 50%, #0F1726 0%, #080B12 60%, #040509 100%);
      overflow: hidden;
    }
    .bg-grid {
      position: absolute; inset: 0; background-size: 60px 60px;
      background-image: linear-gradient(to right, rgba(255, 255, 255, 0.03) 1px, transparent 1px),
                        linear-gradient(to bottom, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
      pointer-events: none;
    }
    .glow-spot {
      position: absolute; width: 800px; height: 800px;
      background: radial-gradient(circle, rgba(30, 136, 229, 0.28) 0%, transparent 70%);
      filter: blur(80px); border-radius: 50%; pointer-events: none;
    }
    .scene {
      position: absolute; inset: 0; display: flex; flex-direction: column;
      align-items: center; justify-content: center; opacity: 0;
      transition: opacity 0.4s ease, transform 0.4s ease; transform: scale(0.96);
      pointer-events: none;
    }
    .scene.active { opacity: 1; transform: scale(1); pointer-events: auto; }
    .pill {
      display: inline-flex; align-items: center; gap: 10px;
      padding: 10px 28px; border-radius: 9999px;
      background: rgba(30, 136, 229, 0.2); border: 1.5px solid rgba(30, 136, 229, 0.5);
      color: #60A5FA; font-size: 20px; font-weight: 800; letter-spacing: 0.08em;
      text-transform: uppercase; margin-bottom: 24px;
    }
    .main-title {
      font-size: 82px; font-weight: 900; line-height: 1.08; text-align: center;
      letter-spacing: -0.03em; margin-bottom: 20px;
    }
    .sub-title {
      font-size: 30px; font-weight: 500; color: #94A3B8; text-align: center;
      max-width: 1100px; line-height: 1.4;
    }
    .highlight-blue {
      background: linear-gradient(135deg, #93C5FD 0%, #3B82F6 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .highlight-emerald {
      background: linear-gradient(135deg, #6EE7B7 0%, #10B981 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .highlight-crimson {
      background: linear-gradient(135deg, #FCA5A5 0%, #EF4444 100%);
      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    }
    .card-row {
      display: flex; gap: 32px; margin-top: 48px;
    }
    .motion-card {
      width: 360px; padding: 28px; border-radius: 24px;
      background: rgba(255, 255, 255, 0.04); border: 1.5px solid rgba(255, 255, 255, 0.1);
      backdrop-filter: blur(20px); box-shadow: 0 20px 50px rgba(0,0,0,0.6);
      transform: translateY(20px); opacity: 0; transition: all 0.5s ease;
    }
    .motion-card.visible { transform: translateY(0); opacity: 1; }
    .brand-box {
      display: flex; align-items: center; gap: 20px; margin-bottom: 24px;
    }
    .brand-icon {
      width: 84px; height: 84px; border-radius: 24px;
      background: linear-gradient(135deg, #1E88E5 0%, #1565C0 100%);
      display: flex; align-items: center; justify-content: center; font-size: 46px;
      box-shadow: 0 12px 36px rgba(30, 136, 229, 0.5);
    }
  </style>
</head>
<body>
  <div id="stage">
    <div class="bg-grid"></div>
    <div class="glow-spot" style="top: -150px; left: 560px;"></div>

    <!-- Scene 1: Intro Hook (0s - 6s) -->
    <div class="scene" id="scene-1">
      <div class="brand-box">
        <div class="brand-icon">📅</div>
        <div style="font-size: 52px; font-weight: 900;">ROCIs Schedule</div>
      </div>
      <div class="pill">📚 The Ultimate Student Companion</div>
      <h1 class="main-title">Master Your Semester. <span class="highlight-blue">Effortlessly.</span></h1>
      <p class="sub-title">Weekly timetables, live GPA calculations, and countdown alarms in one sleek glassmorphic app.</p>
    </div>

    <!-- Scene 2: Timetable & Classes (6s - 12s) -->
    <div class="scene" id="scene-2">
      <div class="pill" style="background: rgba(16, 185, 129, 0.2); border-color: rgba(16, 185, 129, 0.5); color: #34D399;">📅 Weekly Schedule</div>
      <h1 class="main-title">Intuitive Class Timetable. <span class="highlight-emerald">Never Miss a Lecture.</span></h1>
      <div class="card-row">
        <div class="motion-card" id="c1" style="border-left: 6px solid #2196F3;">
          <div style="font-size: 15px; color: #60A5FA; font-weight: 700; margin-bottom: 8px;">10:00 - 12:00 • CS301</div>
          <div style="font-size: 24px; font-weight: 800; margin-bottom: 8px;">Algorithms & Data</div>
          <div style="font-size: 16px; color: #94A3B8;">📍 Turing Hall 101</div>
        </div>
        <div class="motion-card" id="c2" style="border-left: 6px solid #9C27B0;">
          <div style="font-size: 15px; color: #C084FC; font-weight: 700; margin-bottom: 8px;">13:00 - 15:00 • MATH201</div>
          <div style="font-size: 24px; font-weight: 800; margin-bottom: 8px;">Linear Algebra</div>
          <div style="font-size: 16px; color: #94A3B8;">📍 Euler Hall B</div>
        </div>
        <div class="motion-card" id="c3" style="border-left: 6px solid #4CAF50;">
          <div style="font-size: 15px; color: #34D399; font-weight: 700; margin-bottom: 8px;">16:00 - 18:00 • CS405</div>
          <div style="font-size: 24px; font-weight: 800; margin-bottom: 8px;">Machine Learning Lab</div>
          <div style="font-size: 16px; color: #94A3B8;">📍 Silicon Lab 304</div>
        </div>
      </div>
    </div>

    <!-- Scene 3: GPA & Exam Countdown (12s - 18s) -->
    <div class="scene" id="scene-3">
      <div class="pill" style="background: rgba(239, 68, 68, 0.2); border-color: rgba(239, 68, 68, 0.5); color: #F87171;">🚨 Exam & Grade Command</div>
      <h1 class="main-title">Live Exam Alerts & <span class="highlight-crimson">4.0 GPA Tracker.</span></h1>
      <div class="card-row">
        <div class="motion-card" id="c4" style="background: linear-gradient(135deg, rgba(239,68,68,0.15), transparent); border-color: rgba(239,68,68,0.4);">
          <div style="font-size: 15px; font-weight: 800; color: #EF4444; margin-bottom: 8px;">FINAL EXAM ⏳ IN 3 DAYS</div>
          <div style="font-size: 24px; font-weight: 800; margin-bottom: 8px;">Data Structures</div>
          <div style="font-size: 16px; color: #CBD5E1;">Thu, Sep 07 • 09:00</div>
        </div>
        <div class="motion-card" id="c5" style="background: linear-gradient(135deg, rgba(16,185,129,0.15), transparent); border-color: rgba(16,185,129,0.4);">
          <div style="font-size: 15px; font-weight: 800; color: #10B981; margin-bottom: 8px;">CUMULATIVE GPA</div>
          <div style="font-size: 46px; font-weight: 900; color: #34D399; margin-bottom: 4px;">3.88 / 4.0</div>
          <div style="font-size: 16px; color: #CBD5E1;">Weighted Average: 93.6%</div>
        </div>
      </div>
    </div>

    <!-- Scene 4: 1-Click Import & Ecosystem (18s - 24s) -->
    <div class="scene" id="scene-4">
      <div class="pill" style="background: rgba(139, 92, 246, 0.2); border-color: rgba(139, 92, 246, 0.5); color: #C084FC;">⚡ Productivity Supercharged</div>
      <h1 class="main-title">1-Click .ICS Import & <span class="highlight-purple">ROCIs Tasks Bridge.</span></h1>
      <p class="sub-title">Import university schedules from Canvas or Moodle in 1 second. Sync assignments directly into ROCIs Tasks.</p>
    </div>

    <!-- Scene 5: Outro Call to Action (24s - 30s) -->
    <div class="scene" id="scene-5">
      <div class="brand-box">
        <div class="brand-icon">📅</div>
        <div style="font-size: 64px; font-weight: 900;">ROCIs Schedule</div>
      </div>
      <h1 class="main-title" style="margin-bottom: 32px;">Download Today on <span class="highlight-blue">Google Play.</span></h1>
      <div style="display: inline-block; padding: 18px 48px; border-radius: 9999px; background: linear-gradient(135deg, #1E88E5 0%, #1565C0 100%); font-weight: 800; font-size: 26px; box-shadow: 0 12px 40px rgba(30, 136, 229, 0.5);">
        Get It on Google Play ➔
      </div>
    </div>
  </div>

  <script>
    function seekToTime(sec) {
      const s1 = document.getElementById('scene-1');
      const s2 = document.getElementById('scene-2');
      const s3 = document.getElementById('scene-3');
      const s4 = document.getElementById('scene-4');
      const s5 = document.getElementById('scene-5');

      [s1, s2, s3, s4, s5].forEach(s => s.classList.remove('active'));

      if (sec < 6) {
        s1.classList.add('active');
      } else if (sec < 12) {
        s2.classList.add('active');
        document.getElementById('c1').classList.add('visible');
        document.getElementById('c2').classList.add('visible');
        document.getElementById('c3').classList.add('visible');
      } else if (sec < 18) {
        s3.classList.add('active');
        document.getElementById('c4').classList.add('visible');
        document.getElementById('c5').classList.add('visible');
      } else if (sec < 24) {
        s4.classList.add('active');
      } else {
        s5.classList.add('active');
      }
    }

    // Default play preview
    let currentSec = 0;
    setInterval(() => {
      seekToTime(currentSec);
      currentSec = (currentSec + 1) % 30;
    }, 1000);
  </script>
</body>
</html>
"""
    with open(VIDEO_HTML_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print("Generated video_trailer_16_9.html successfully.")

if __name__ == "__main__":
    generate_screenshots_html()
    generate_video_html()
