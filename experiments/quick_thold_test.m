%% quick_test_rho03.m
% rho=0.3 저부하 환경 테스트
% Baseline vs T_hold=120ms 비교 (상세 분석)

clear; clc;
addpath(genpath(pwd));

%% 설정
sim_time = 30.0;
num_stas = 20;
rho = 0.3;
mu_on = 0.05;   % 50ms (고정 - rho=0.5와 동일)
mu_off = mu_on * (1 - rho) / rho;  % 117ms
lambda = 50;
thold_value = 0.120;  % 120ms (Coverage ≈ 103%)

fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║     rho=0.3 저부하 환경 테스트                                       ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  sim_time = %.1fs, STAs = %d, rho = %.1f                             ║\n', sim_time, num_stas, rho);
fprintf('║  mu_on = %.0fms (고정), mu_off = %.0fms                              ║\n', mu_on*1000, mu_off*1000);
fprintf('║  T_hold = %.0fms (Coverage = %.0f%%)                                  ║\n', thold_value*1000, thold_value/(mu_off)*100);
fprintf('║  버스트당 패킷: %.1f개 (rho=0.5와 동일)                              ║\n', lambda * mu_on);
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════
%  Baseline (T_hold OFF)
%  ═══════════════════════════════════════════════════════════════════════
fprintf('[1/2] Baseline (T_hold OFF) 실행 중...\n');

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
fprintf('  완료!\n');

%% ═══════════════════════════════════════════════════════════════════════
%  T_hold = 120ms
%  ═══════════════════════════════════════════════════════════════════════
fprintf('\n[2/2] T_hold = 120ms 실행 중...\n');

cfg.thold_enabled = true;
cfg.thold_value = thold_value;
cfg.seed = 12345;

r_thold = run_simulation(cfg);
fprintf('  완료!\n');

%% ═══════════════════════════════════════════════════════════════════════
%  결과 분석
%  ═══════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                         결과 분석                                    ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

%% 1. Delay 지표
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  1. Delay 지표                                                      │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │ %10s │\n', '', 'Baseline', 'T=120ms', '변화');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');

% Mean Delay
base_mean = r_base.delay.mean_ms;
thold_mean = r_thold.delay.mean_ms;
change_mean = (thold_mean - base_mean) / base_mean * 100;
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'Mean Delay', base_mean, thold_mean, change_mean);

% P90 Delay
base_p90 = r_base.delay.p90_ms;
thold_p90 = r_thold.delay.p90_ms;
change_p90 = (thold_p90 - base_p90) / base_p90 * 100;
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'P90 Delay', base_p90, thold_p90, change_p90);

% Std Delay
base_std = r_base.delay.std_ms;
thold_std = r_thold.delay.std_ms;
change_std = (thold_std - base_std) / base_std * 100;
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'Std Delay', base_std, thold_std, change_std);

% Max Delay
base_max = r_base.delay.max_ms;
thold_max = r_thold.delay.max_ms;
change_max = (thold_max - base_max) / base_max * 100;
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'Max Delay', base_max, thold_max, change_max);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% 2. Delay Decomposition
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  2. Delay Decomposition                                             │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │ %10s │\n', '', 'Baseline', 'T=120ms', '변화');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');

% Initial Wait
base_init = r_base.delay.decomposition.initial_wait_ms;
thold_init = r_thold.delay.decomposition.initial_wait_ms;
if base_init > 0
    change_init = (thold_init - base_init) / base_init * 100;
else
    change_init = 0;
end
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'Initial Wait', base_init, thold_init, change_init);

% UORA Contention
base_uora = r_base.delay.decomposition.uora_contention_ms;
thold_uora = r_thold.delay.decomposition.uora_contention_ms;
if base_uora > 0
    change_uora = (thold_uora - base_uora) / base_uora * 100;
else
    change_uora = 0;
end
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'UORA Contention', base_uora, thold_uora, change_uora);

% SA Wait
base_sa = r_base.delay.decomposition.sa_wait_ms;
thold_sa = r_thold.delay.decomposition.sa_wait_ms;
if base_sa > 0
    change_sa = (thold_sa - base_sa) / base_sa * 100;
else
    change_sa = 0;
end
fprintf('│  %-20s │ %10.2f ms │ %10.2f ms │ %+9.1f%% │\n', 'SA Wait', base_sa, thold_sa, change_sa);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% 3. Collision & Throughput
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  3. Collision & Throughput                                          │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │ %10s │\n', '', 'Baseline', 'T=120ms', '변화');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');

% Collision Rate
base_coll = r_base.uora.collision_rate * 100;
thold_coll = r_thold.uora.collision_rate * 100;
if base_coll > 0
    change_coll = (thold_coll - base_coll) / base_coll * 100;
else
    change_coll = 0;
end
fprintf('│  %-20s │ %10.1f %% │ %10.1f %% │ %+9.1f%% │\n', 'Collision Rate', base_coll, thold_coll, change_coll);

% Throughput
base_thru = r_base.throughput.total_mbps;
thold_thru = r_thold.throughput.total_mbps;
change_thru = (thold_thru - base_thru) / base_thru * 100;
fprintf('│  %-20s │ %10.2f   │ %10.2f   │ %+9.1f%% │\n', 'Throughput (Mbps)', base_thru, thold_thru, change_thru);

% Completion Rate
base_comp = r_base.packets.completion_rate * 100;
thold_comp = r_thold.packets.completion_rate * 100;
change_comp = thold_comp - base_comp;  % percentage point 변화
fprintf('│  %-20s │ %10.1f %% │ %10.1f %% │ %+8.1f%%p │\n', 'Completion Rate', base_comp, thold_comp, change_comp);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% 4. Utilization
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  4. Utilization                                                     │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │ %10s │\n', '', 'Baseline', 'T=120ms', '변화');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');

% RA Utilization
base_ra = r_base.throughput.ra_utilization * 100;
thold_ra = r_thold.throughput.ra_utilization * 100;
if base_ra > 0
    change_ra = (thold_ra - base_ra) / base_ra * 100;
else
    change_ra = 0;
end
fprintf('│  %-20s │ %10.1f %% │ %10.1f %% │ %+9.1f%% │\n', 'RA Util', base_ra, thold_ra, change_ra);

% SA Alloc Hit (= SA Utilization)
base_sa_hit = r_base.throughput.sa_utilization * 100;
thold_sa_hit = r_thold.throughput.sa_utilization * 100;
change_sa_hit = thold_sa_hit - base_sa_hit;
fprintf('│  %-20s │ %10.1f %% │ %10.1f %% │ %+8.1f%%p │\n', 'SA Alloc Hit', base_sa_hit, thold_sa_hit, change_sa_hit);

% Channel Utilization
base_ch = r_base.throughput.channel_utilization * 100;
thold_ch = r_thold.throughput.channel_utilization * 100;
if base_ch > 0
    change_ch = (thold_ch - base_ch) / base_ch * 100;
else
    change_ch = 0;
end
fprintf('│  %-20s │ %10.1f %% │ %10.1f %% │ %+9.1f%% │\n', 'Channel Util', base_ch, thold_ch, change_ch);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% 5. BSR Count
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  5. BSR Count                                                       │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │ %10s │\n', '', 'Baseline', 'T=120ms', '변화');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');

% Implicit BSR
base_imp = r_base.bsr.implicit_count;
thold_imp = r_thold.bsr.implicit_count;
if base_imp > 0
    change_imp = (thold_imp - base_imp) / base_imp * 100;
else
    change_imp = 0;
end
fprintf('│  %-20s │ %10d   │ %10d   │ %+9.1f%% │\n', 'Implicit BSR', base_imp, thold_imp, change_imp);

% Explicit BSR
base_exp = r_base.bsr.explicit_count;
thold_exp = r_thold.bsr.explicit_count;
if base_exp > 0
    change_exp = (thold_exp - base_exp) / base_exp * 100;
else
    change_exp = 0;
end
fprintf('│  %-20s │ %10d   │ %10d   │ %+9.1f%% │\n', 'Explicit BSR', base_exp, thold_exp, change_exp);

% Explicit Ratio
base_total = base_imp + base_exp;
thold_total = thold_imp + thold_exp;
base_exp_ratio = base_exp / base_total * 100;
thold_exp_ratio = thold_exp / thold_total * 100;
fprintf('│  %-20s │ %10.1f %% │ %10.1f %% │            │\n', 'Explicit Ratio', base_exp_ratio, thold_exp_ratio);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% 6. T_hold 지표
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  6. T_hold 지표                                                     │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │            │\n', '', 'Baseline', 'T=120ms');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %10d   │            │\n', 'Activations', 'N/A', r_thold.thold.activations);
fprintf('│  %-20s │ %12s │ %10d   │            │\n', 'Hits', 'N/A', r_thold.thold.hits);
fprintf('│  %-20s │ %12s │ %10d   │            │\n', 'Expirations', 'N/A', r_thold.thold.expirations);
fprintf('│  %-20s │ %12s │ %10.1f %% │            │\n', 'Hit Rate', 'N/A', r_thold.thold.hit_rate * 100);
fprintf('│  %-20s │ %12s │ %10d   │            │\n', 'Phantom', 'N/A', r_thold.thold.phantom_count);

% Phantom vs Hits 비율
phantom_ratio = r_thold.thold.phantom_count / max(r_thold.thold.hits, 1);
fprintf('│  %-20s │ %12s │ %10.1f x │            │\n', 'Phantom/Hits', 'N/A', phantom_ratio);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% 7. Fairness
fprintf('┌─────────────────────────────────────────────────────────────────────┐\n');
fprintf('│  7. Fairness                                                        │\n');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');
fprintf('│  %-20s │ %12s │ %12s │ %10s │\n', '', 'Baseline', 'T=120ms', '변화');
fprintf('├─────────────────────────────────────────────────────────────────────┤\n');

% Jain Index
base_jain = r_base.fairness.jain_index;
thold_jain = r_thold.fairness.jain_index;
change_jain = thold_jain - base_jain;
fprintf('│  %-20s │ %10.3f   │ %10.3f   │ %+9.3f │\n', 'Jain Index', base_jain, thold_jain, change_jain);

% Min/Max Ratio
base_minmax = r_base.fairness.min_max_ratio;
thold_minmax = r_thold.fairness.min_max_ratio;
change_minmax = thold_minmax - base_minmax;
fprintf('│  %-20s │ %10.3f   │ %10.3f   │ %+9.3f │\n', 'Min/Max Ratio', base_minmax, thold_minmax, change_minmax);

fprintf('└─────────────────────────────────────────────────────────────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════
%  rho=0.5 결과와 비교
%  ═══════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  참고: rho=0.5 결과 (STA=20, T=50ms)                                 ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  Baseline: Delay=105ms, Collision=33%%, Completion=99.7%%            ║\n');
fprintf('║  T=50ms:   Delay=10ms (-90%%), Collision=4%%, Completion=83.5%%       ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════
%  핵심 요약
%  ═══════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                         핵심 요약                                    ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  rho=0.3 저부하 환경 (mu_on=50ms, mu_off=117ms)                      ║\n');
fprintf('╟──────────────────────────────────────────────────────────────────────╢\n');

% Baseline 상태 판단
if base_coll < 10
    fprintf('║  [Baseline 상태] 충돌률 %.1f%% → 이미 양호                         ║\n', base_coll);
else
    fprintf('║  [Baseline 상태] 충돌률 %.1f%% → 개선 여지 있음                    ║\n', base_coll);
end

if base_mean < 50
    fprintf('║  [Baseline 상태] 지연 %.1fms → 이미 양호                           ║\n', base_mean);
else
    fprintf('║  [Baseline 상태] 지연 %.1fms → 개선 여지 있음                      ║\n', base_mean);
end

fprintf('╟──────────────────────────────────────────────────────────────────────╢\n');

% T_hold 효과 판단
if change_mean < -50
    fprintf('║  [T_hold 효과] 지연 %.1f%% 감소 → 효과 큼                          ║\n', -change_mean);
elseif change_mean < -20
    fprintf('║  [T_hold 효과] 지연 %.1f%% 감소 → 효과 중간                        ║\n', -change_mean);
else
    fprintf('║  [T_hold 효과] 지연 %.1f%% 감소 → 효과 제한적                      ║\n', -change_mean);
end

if change_comp < -20
    fprintf('║  [T_hold 부작용] Completion %.1f%%p 감소 → 심각                    ║\n', change_comp);
elseif change_comp < -5
    fprintf('║  [T_hold 부작용] Completion %.1f%%p 감소 → 중간                    ║\n', change_comp);
else
    fprintf('║  [T_hold 부작용] Completion %.1f%%p 변화 → 양호                    ║\n', change_comp);
end

fprintf('╚══════════════════════════════════════════════════════════════════════╝\n');

fprintf('\n실험 완료!\n');