%% test_m2_quick.m
% M2 기법 빠른 검증 테스트
%
% 확인 사항:
%   1. T_hold 동안 Phantom = 0 (SA-RU 할당 안 받음)
%   2. waiting_final에서 Case 분류 정확성
%   3. clean_exp vs exp_with_data 분류

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    M2 빠른 검증 테스트                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 설정
cfg = config_default();
cfg.simulation_time = 10;  % 짧게
cfg.seed = 1234;
cfg.verbose = 0;

% 트래픽: 시나리오 A
cfg.traffic_model = 'pareto_onoff';
cfg.lambda = 100;
cfg.rho = 0.3;
cfg.mu_off = 0.050;
cfg.mu_on = cfg.rho * cfg.mu_off / (1 - cfg.rho);
cfg.pareto_alpha = 1.5;

% T_hold 설정
cfg.thold_enabled = true;
cfg.thold_value = 0.050;  % 50ms

%% 테스트 1: M0 vs M2 Phantom 비교
fprintf('[테스트 1] M0 vs M2 Phantom 비교\n');
fprintf('─────────────────────────────────────────────\n');

% M0 실행
cfg.thold_method = 'M0';
r_m0 = run_simulation(cfg);

% M2 실행
cfg.thold_method = 'M2';
r_m2 = run_simulation(cfg);

fprintf('  M0 Phantom: %d\n', r_m0.thold.phantoms);
fprintf('  M2 Phantom: %d\n', r_m2.thold.phantoms);

if r_m2.thold.phantoms < r_m0.thold.phantoms
    fprintf('  ✓ M2 Phantom < M0 Phantom 확인 (%d < %d)\n', r_m2.thold.phantoms, r_m0.thold.phantoms);
    reduction = (1 - r_m2.thold.phantoms / r_m0.thold.phantoms) * 100;
    fprintf('    Phantom 감소율: %.1f%%\n', reduction);
end

%% 테스트 2: M2 Case 분류 검증
fprintf('\n[테스트 2] M2 Case 분류 검증\n');
fprintf('─────────────────────────────────────────────\n');

fprintf('  Activations: %d\n', r_m2.thold.activations);
fprintf('  Hits: %d\n', r_m2.thold.hits);
fprintf('  Phantoms: %d\n', r_m2.thold.phantoms);
fprintf('  Clean Exp (할당실패+empty): %d\n', r_m2.thold.clean_exp);
fprintf('  Exp with Data (할당실패+data): %d\n', r_m2.thold.exp_with_data);

% M2 검증: Activations = Hits + Phantoms + Clean_Exp + Exp_with_Data
% (시뮬레이션 종료 시 waiting_final 상태 STA로 인해 약간의 차이 허용)
expected_total = r_m2.thold.hits + r_m2.thold.phantoms + r_m2.thold.clean_exp + r_m2.thold.exp_with_data;
diff = r_m2.thold.activations - expected_total;

if diff >= 0 && diff <= 20  % STA 수(20) 이하 차이는 정상
    fprintf('  ✓ M2 통계 검증 통과\n');
    fprintf('    Activations(%d) = Hits(%d) + Phantoms(%d) + Clean(%d) + ExpData(%d) + 경계오차(%d)\n', ...
        r_m2.thold.activations, r_m2.thold.hits, r_m2.thold.phantoms, ...
        r_m2.thold.clean_exp, r_m2.thold.exp_with_data, diff);
else
    fprintf('  ⚠️ 불일치! Activations(%d) vs 합계(%d), 차이: %d\n', ...
        r_m2.thold.activations, expected_total, diff);
end

%% 테스트 3: 성능 비교
fprintf('\n[테스트 3] M0 vs M2 성능 비교\n');
fprintf('─────────────────────────────────────────────\n');

fprintf('                    M0          M2\n');
fprintf('  Mean Delay:    %6.1f ms   %6.1f ms\n', r_m0.delay.mean_ms, r_m2.delay.mean_ms);
fprintf('  P90 Delay:     %6.1f ms   %6.1f ms\n', r_m0.delay.p90_ms, r_m2.delay.p90_ms);
fprintf('  Completion:    %6.1f %%    %6.1f %%\n', r_m0.packets.completion_rate*100, r_m2.packets.completion_rate*100);
fprintf('  Hit Rate:      %6.1f %%    %6.1f %%\n', r_m0.thold.hit_rate*100, r_m2.thold.hit_rate*100);
fprintf('  Phantoms:      %6d       %6d\n', r_m0.thold.phantoms, r_m2.thold.phantoms);

%% 테스트 4: Baseline vs M2 비교
fprintf('\n[테스트 4] Baseline vs M2 비교\n');
fprintf('─────────────────────────────────────────────\n');

% Baseline
cfg.thold_enabled = false;
r_base = run_simulation(cfg);

fprintf('                 Baseline      M2\n');
fprintf('  Mean Delay:    %6.1f ms   %6.1f ms\n', r_base.delay.mean_ms, r_m2.delay.mean_ms);
fprintf('  P90 Delay:     %6.1f ms   %6.1f ms\n', r_base.delay.p90_ms, r_m2.delay.p90_ms);
fprintf('  Completion:    %6.1f %%    %6.1f %%\n', r_base.packets.completion_rate*100, r_m2.packets.completion_rate*100);

delay_improve = (r_base.delay.mean_ms - r_m2.delay.mean_ms) / r_base.delay.mean_ms * 100;
fprintf('\n  지연 개선율: %.1f%%\n', delay_improve);

%% 결과 요약
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('  테스트 완료\n');
fprintf('═══════════════════════════════════════════════════════════════════\n');