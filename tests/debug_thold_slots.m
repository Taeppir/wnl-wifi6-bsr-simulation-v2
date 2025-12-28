%% debug_thold_value.m
% T_hold 값이 제대로 적용되는지 디버깅

clear; clc;
addpath(genpath(pwd));

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  T_hold 값 디버깅\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% 테스트 1: thold_value = 5ms
fprintf('[Test 1] thold_value = 5ms (0.005초)\n');
cfg1 = config_default();
cfg1.thold_enabled = true;
cfg1.thold_value = 0.005;

% validate_config 수동 호출
cfg1.total_slots = ceil(cfg1.simulation_time / cfg1.slot_duration);
cfg1.warmup_slots = ceil(cfg1.warmup_time / cfg1.slot_duration);
cfg1.thold_slots = ceil(cfg1.thold_value / cfg1.slot_duration);

fprintf('  cfg.thold_value = %.4f초\n', cfg1.thold_value);
fprintf('  cfg.thold_slots = %d 슬롯\n', cfg1.thold_slots);
fprintf('  cfg.slot_duration = %.6f초\n', cfg1.slot_duration);
fprintf('  실제 T_hold = %.2f ms\n\n', cfg1.thold_slots * cfg1.slot_duration * 1000);

%% 테스트 2: thold_value = 10ms
fprintf('[Test 2] thold_value = 10ms (0.010초)\n');
cfg2 = config_default();
cfg2.thold_enabled = true;
cfg2.thold_value = 0.010;

cfg2.total_slots = ceil(cfg2.simulation_time / cfg2.slot_duration);
cfg2.warmup_slots = ceil(cfg2.warmup_time / cfg2.slot_duration);
cfg2.thold_slots = ceil(cfg2.thold_value / cfg2.slot_duration);

fprintf('  cfg.thold_value = %.4f초\n', cfg2.thold_value);
fprintf('  cfg.thold_slots = %d 슬롯\n', cfg2.thold_slots);
fprintf('  실제 T_hold = %.2f ms\n\n', cfg2.thold_slots * cfg2.slot_duration * 1000);

%% 테스트 3: thold_value = 30ms
fprintf('[Test 3] thold_value = 30ms (0.030초)\n');
cfg3 = config_default();
cfg3.thold_enabled = true;
cfg3.thold_value = 0.030;

cfg3.total_slots = ceil(cfg3.simulation_time / cfg3.slot_duration);
cfg3.warmup_slots = ceil(cfg3.warmup_time / cfg3.slot_duration);
cfg3.thold_slots = ceil(cfg3.thold_value / cfg3.slot_duration);

fprintf('  cfg.thold_value = %.4f초\n', cfg3.thold_value);
fprintf('  cfg.thold_slots = %d 슬롯\n', cfg3.thold_slots);
fprintf('  실제 T_hold = %.2f ms\n\n', cfg3.thold_slots * cfg3.slot_duration * 1000);

%% 테스트 4: thold_value = 50ms
fprintf('[Test 4] thold_value = 50ms (0.050초)\n');
cfg4 = config_default();
cfg4.thold_enabled = true;
cfg4.thold_value = 0.050;

cfg4.total_slots = ceil(cfg4.simulation_time / cfg4.slot_duration);
cfg4.warmup_slots = ceil(cfg4.warmup_time / cfg4.slot_duration);
cfg4.thold_slots = ceil(cfg4.thold_value / cfg4.slot_duration);

fprintf('  cfg.thold_value = %.4f초\n', cfg4.thold_value);
fprintf('  cfg.thold_slots = %d 슬롯\n', cfg4.thold_slots);
fprintf('  실제 T_hold = %.2f ms\n\n', cfg4.thold_slots * cfg4.slot_duration * 1000);

%% TF 주기 확인
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  TF 주기 정보\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  frame_exchange_slots = %d\n', cfg1.frame_exchange_slots);
fprintf('  TF 주기 = %.2f ms\n', cfg1.frame_exchange_slots * cfg1.slot_duration * 1000);

%% 시뮬레이션 실행 테스트
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  실제 시뮬레이션 테스트 (짧게)\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

sim_time = 2.0;

% 5ms 테스트
fprintf('[Run 1] T_hold = 5ms\n');
cfg = config_default();
cfg.simulation_time = sim_time;
cfg.warmup_time = 0;
cfg.num_stas = 10;
cfg.thold_enabled = true;
cfg.thold_value = 0.005;
cfg.verbose = 0;
cfg.seed = 9999;

r1 = run_simulation(cfg);
fprintf('  activations=%d, hits=%d, phantom=%d, expirations=%d\n', ...
    r1.thold.activations, r1.thold.hits, r1.thold.phantom_count, r1.thold.expirations);

% 50ms 테스트
fprintf('[Run 2] T_hold = 50ms\n');
cfg.thold_value = 0.050;
cfg.seed = 9999;

r2 = run_simulation(cfg);
fprintf('  activations=%d, hits=%d, phantom=%d, expirations=%d\n', ...
    r2.thold.activations, r2.thold.hits, r2.thold.phantom_count, r2.thold.expirations);

%% 비교
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  비교 결과\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
if r1.thold.hits == r2.thold.hits && r1.thold.phantom_count == r2.thold.phantom_count
    fprintf('⚠️  버그 확인: 5ms와 50ms 결과가 완전히 동일!\n');
    fprintf('    T_hold 값이 제대로 적용되지 않고 있음\n');
else
    fprintf('✓ 정상: 5ms와 50ms 결과가 다름\n');
    fprintf('  5ms:  hits=%d, phantom=%d\n', r1.thold.hits, r1.thold.phantom_count);
    fprintf('  50ms: hits=%d, phantom=%d\n', r2.thold.hits, r2.thold.phantom_count);
end