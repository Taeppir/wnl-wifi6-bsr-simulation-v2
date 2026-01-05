%% BSR 분석 스크립트
load('results/main_m0_m1/results.mat');
fprintf('\n=== BSR Count 분석 (시나리오 A, T_hold=30ms) ===\n\n');

% Baseline
r = results.runs.A_Baseline_s1;
fprintf('Baseline:\n');
fprintf('  Implicit BSR: %d\n', r.bsr.implicit_count);
fprintf('  Explicit BSR: %d\n', r.bsr.explicit_count);
fprintf('  Packets completed: %d\n', r.packets.completed);
fprintf('  UORA attempts: %d\n\n', r.uora.total_attempts);

% M0
r = results.runs.A_T30_M0_s1;
fprintf('M0:\n');
fprintf('  Implicit BSR: %d\n', r.bsr.implicit_count);
fprintf('  Explicit BSR: %d\n', r.bsr.explicit_count);
fprintf('  Packets completed: %d\n', r.packets.completed);
fprintf('  UORA attempts: %d\n', r.uora.total_attempts);
fprintf('  Hit rate: %.1f%%\n\n', r.thold.hit_rate * 100);

% M1(5)
r = results.runs.A_T30_M1_5_s1;
fprintf('M1(5):\n');
fprintf('  Implicit BSR: %d\n', r.bsr.implicit_count);
fprintf('  Explicit BSR: %d\n', r.bsr.explicit_count);
fprintf('  Packets completed: %d\n', r.packets.completed);
fprintf('  UORA attempts: %d\n\n', r.uora.total_attempts);

load('results/main_m2/results.mat');
r = results.runs.A_T30_M2_s1;
fprintf('M2:\n');
fprintf('  Implicit BSR: %d\n', r.bsr.implicit_count);
fprintf('  Explicit BSR: %d\n', r.bsr.explicit_count);
fprintf('  Packets completed: %d\n', r.packets.completed);
fprintf('  UORA attempts: %d\n', r.uora.total_attempts);