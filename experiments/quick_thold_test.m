%% quick_thold_test.m
% 빠른 T_hold 디버깅용 실험
% 5초 시뮬레이션, Baseline vs T_hold 비교

clear; clc;
addpath(genpath(pwd));

%% 설정
sim_time = 10.0;
num_stas = 20;
rho = 0.5;
mu_on = 0.05;  % 50ms
mu_off = mu_on * (1 - rho) / rho;  % 50ms
lambda = 50;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Quick T_hold Test\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  sim_time = %.1fs, STAs = %d, rho = %.1f\n', sim_time, num_stas, rho);
fprintf('  mu_on = %.0fms, mu_off = %.0fms\n', mu_on*1000, mu_off*1000);
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Baseline (T_hold OFF)
fprintf('[1/3] Baseline (T_hold OFF)...\n');

cfg = config_default();
cfg.simulation_time = sim_time;
cfg.warmup_time = 0.0;
cfg.num_stas = num_stas;
cfg.rho = rho;
cfg.mu_on = mu_on;
cfg.mu_off = mu_off;
cfg.lambda = lambda;
cfg.thold_enabled = false;
cfg.verbose = 0;
cfg.seed = 12345;

r_base = run_simulation(cfg);

fprintf('  Delay: %.2f ms\n', r_base.delay.mean_ms);
fprintf('  Collision: %.1f%%\n', r_base.uora.collision_rate * 100);
fprintf('  Completion: %.1f%%\n', r_base.packets.completion_rate * 100);
fprintf('  Explicit BSR: %d, Implicit BSR: %d\n', r_base.bsr.explicit_count, r_base.bsr.implicit_count);

%% T_hold = 30ms
fprintf('\n[2/3] T_hold = 30ms...\n');

cfg.thold_enabled = true;
cfg.thold_value = 0.030;  % 30ms
cfg.seed = 12345;  % 동일 시드

r_30 = run_simulation(cfg);

fprintf('  Delay: %.2f ms (%.1f%% 변화)\n', r_30.delay.mean_ms, ...
    (r_30.delay.mean_ms - r_base.delay.mean_ms) / r_base.delay.mean_ms * 100);
fprintf('  Collision: %.1f%%\n', r_30.uora.collision_rate * 100);
fprintf('  Completion: %.1f%%\n', r_30.packets.completion_rate * 100);
fprintf('  Explicit BSR: %d, Implicit BSR: %d\n', r_30.bsr.explicit_count, r_30.bsr.implicit_count);
fprintf('  T_hold: activations=%d, hits=%d, hit_rate=%.1f%%, phantom=%d, expirations=%d\n', ...
    r_30.thold.activations, r_30.thold.hits, r_30.thold.hit_rate * 100, ...
    r_30.thold.phantom_count, r_30.thold.expirations);

%% T_hold = 50ms
fprintf('\n[3/3] T_hold = 50ms...\n');

cfg.thold_value = 0.050;  % 50ms
cfg.seed = 12345;  % 동일 시드

r_50 = run_simulation(cfg);

fprintf('  Delay: %.2f ms (%.1f%% 변화)\n', r_50.delay.mean_ms, ...
    (r_50.delay.mean_ms - r_base.delay.mean_ms) / r_base.delay.mean_ms * 100);
fprintf('  Collision: %.1f%%\n', r_50.uora.collision_rate * 100);
fprintf('  Completion: %.1f%%\n', r_50.packets.completion_rate * 100);
fprintf('  Explicit BSR: %d, Implicit BSR: %d\n', r_50.bsr.explicit_count, r_50.bsr.implicit_count);
fprintf('  T_hold: activations=%d, hits=%d, hit_rate=%.1f%%, phantom=%d, expirations=%d\n', ...
    r_50.thold.activations, r_50.thold.hits, r_50.thold.hit_rate * 100, ...
    r_50.thold.phantom_count, r_50.thold.expirations);

%% 비교 요약
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  요약 비교\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('%-15s | %-12s | %-12s | %-12s\n', '', 'Baseline', 'T_hold=30ms', 'T_hold=50ms');
fprintf('───────────────────────────────────────────────────────────────\n');
fprintf('%-15s | %10.2f ms | %10.2f ms | %10.2f ms\n', 'Delay', ...
    r_base.delay.mean_ms, r_30.delay.mean_ms, r_50.delay.mean_ms);
fprintf('%-15s | %10.1f %% | %10.1f %% | %10.1f %%\n', 'Collision', ...
    r_base.uora.collision_rate*100, r_30.uora.collision_rate*100, r_50.uora.collision_rate*100);
fprintf('%-15s | %10.1f %% | %10.1f %% | %10.1f %%\n', 'Completion', ...
    r_base.packets.completion_rate*100, r_30.packets.completion_rate*100, r_50.packets.completion_rate*100);
fprintf('%-15s | %10d   | %10d   | %10d\n', 'Explicit BSR', ...
    r_base.bsr.explicit_count, r_30.bsr.explicit_count, r_50.bsr.explicit_count);
fprintf('%-15s | %10d   | %10d   | %10d\n', 'Implicit BSR', ...
    r_base.bsr.implicit_count, r_30.bsr.implicit_count, r_50.bsr.implicit_count);
fprintf('%-15s | %10s   | %10d   | %10d\n', 'T_hold Hits', ...
    'N/A', r_30.thold.hits, r_50.thold.hits);
fprintf('%-15s | %10s   | %10d   | %10d\n', 'Phantom', ...
    'N/A', r_30.thold.phantom_count, r_50.thold.phantom_count);
fprintf('═══════════════════════════════════════════════════════════════\n');

%% 이상 여부 체크
fprintf('\n[이상 여부 체크]\n');
if r_30.thold.hits == r_50.thold.hits
    fprintf('⚠️  경고: T_hold 30ms와 50ms의 Hits가 동일함!\n');
end
if r_30.thold.phantom_count == r_50.thold.phantom_count
    fprintf('⚠️  경고: T_hold 30ms와 50ms의 Phantom이 동일함!\n');
end
if r_30.delay.mean_ms > r_base.delay.mean_ms * 1.05
    fprintf('⚠️  경고: T_hold=30ms가 Baseline보다 5%% 이상 지연 증가!\n');
end
if r_50.delay.mean_ms > r_base.delay.mean_ms * 1.05
    fprintf('⚠️  경고: T_hold=50ms가 Baseline보다 5%% 이상 지연 증가!\n');
end
if r_30.thold.hit_rate < 0.1
    fprintf('⚠️  경고: T_hold=30ms Hit Rate가 10%% 미만!\n');
end

fprintf('\n실험 완료!\n');