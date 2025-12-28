%% quick_validation.m
% 코드 검증용: Phase 1, 2, 3 각 1개씩만 빠르게 실행
%
% 목적: 새 지표들이 제대로 수집되는지 확인

clear; clc;
addpath(genpath(pwd));

sim_time = 5.0;  % 빠른 검증용
mu_on = 0.05;

fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Quick Validation: 새 지표 수집 확인\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

%% Phase 1: Baseline 1개
fprintf('[Phase 1] Baseline (STA=40, rho=0.5)...\n');
cfg = config_default();
cfg.simulation_time = sim_time;
cfg.warmup_time = 0.0;
cfg.num_stas = 20;
cfg.rho = 0.5;
cfg.mu_on = mu_on;
cfg.mu_off = mu_on * (1 - cfg.rho) / cfg.rho;
cfg.lambda = 50;
cfg.thold_enabled = false;
cfg.verbose = 0;
cfg.seed = 1234;

r1 = run_simulation(cfg);
r1.exp_id = 'V-B1';
r1.phase = 1;
r1.config = cfg;

fprintf('  Delay: %.1f ms\n', r1.delay.mean_ms);
fprintf('  Completion: %.1f%%\n', r1.packets.completion_rate * 100);
fprintf('  Collision: %.1f%%\n', r1.uora.collision_rate * 100);
fprintf('  Jain Index: %.4f\n', r1.fairness.jain_index);
fprintf('  CoV: %.4f\n', r1.fairness.cov);
fprintf('  MinMax Ratio: %.4f\n', r1.fairness.min_max_ratio);

%% Phase 2: T_hold=50ms 1개
fprintf('\n[Phase 2] T_hold=50ms (STA=40, rho=0.5)...\n');
cfg.thold_enabled = true;
cfg.thold_value = 0.050;
cfg.seed = 2345;

r2 = run_simulation(cfg);
r2.exp_id = 'V-T1';
r2.phase = 2;
r2.config = cfg;

fprintf('  Delay: %.1f ms\n', r2.delay.mean_ms);
fprintf('  Completion: %.1f%%\n', r2.packets.completion_rate * 100);
fprintf('  Collision: %.1f%%\n', r2.uora.collision_rate * 100);
fprintf('  --- T_hold 지표 ---\n');
fprintf('  Activations: %d\n', r2.thold.activations);
fprintf('  Hits: %d\n', r2.thold.hits);
fprintf('  Expirations: %d\n', r2.thold.expirations);
fprintf('  Hit Rate: %.1f%%\n', r2.thold.hit_rate * 100);
fprintf('  Phantom Count: %d\n', r2.thold.phantom_count);

%% Phase 3: rho=0.3 1개
fprintf('\n[Phase 3] T_hold=50ms (STA=40, rho=0.3)...\n');
cfg.rho = 0.3;
cfg.mu_off = mu_on * (1 - cfg.rho) / cfg.rho;
cfg.seed = 3456;

r3 = run_simulation(cfg);
r3.exp_id = 'V-R1';
r3.phase = 3;
r3.config = cfg;

coverage = cfg.thold_value / cfg.mu_off * 100;
fprintf('  Coverage: %.0f%%\n', coverage);
fprintf('  Delay: %.1f ms\n', r3.delay.mean_ms);
fprintf('  Completion: %.1f%%\n', r3.packets.completion_rate * 100);
fprintf('  Hit Rate: %.1f%%\n', r3.thold.hit_rate * 100);
fprintf('  Expirations: %d\n', r3.thold.expirations);

%% summarize_results 테스트
fprintf('\n[summarize_results 테스트]\n');
try
    s1 = summarize_results(r1, r1.config);
    s2 = summarize_results(r2, r2.config);
    s3 = summarize_results(r3, r3.config);
    
    fprintf('  ✓ Phase 1 요약: %d 필드\n', length(fieldnames(s1)));
    fprintf('  ✓ Phase 2 요약: %d 필드\n', length(fieldnames(s2)));
    fprintf('  ✓ Phase 3 요약: %d 필드\n', length(fieldnames(s3)));
    
    % 필드 확인
    check_fields = {'thold_activations', 'thold_hits', 'thold_expirations', ...
                    'thold_hit_rate', 'thold_phantom_count', 'min_max_ratio', 'thold_coverage'};
    fprintf('\n  필드 확인:\n');
    for i = 1:length(check_fields)
        if isfield(s2, check_fields{i})
            val = s2.(check_fields{i});
            if val == floor(val)
                fprintf('    ✓ %s = %d\n', check_fields{i}, val);
            else
                fprintf('    ✓ %s = %.4f\n', check_fields{i}, val);
            end
        else
            fprintf('    ✗ %s 없음!\n', check_fields{i});
        end
    end
    
    fprintf('\n  ✓ summarize_results 정상 작동!\n');
catch ME
    fprintf('  ✗ 에러: %s\n', ME.message);
end

%% CSV 저장 테스트
fprintf('\n[CSV 저장 테스트]\n');
try
    test_results = [s1; s2; s3];
    test_table = struct2table(test_results);
    
    if ~exist('results/summary', 'dir')
        mkdir('results/summary');
    end
    writetable(test_table, 'results/summary/validation_test.csv');
    fprintf('  ✓ CSV 저장 성공: results/summary/validation_test.csv\n');
    fprintf('  ✓ 컬럼 수: %d\n', width(test_table));
catch ME
    fprintf('  ✗ 에러: %s\n', ME.message);
end

%% 완료
fprintf('\n═══════════════════════════════════════════════════════════════\n');
fprintf('  검증 완료!\n');
fprintf('═══════════════════════════════════════════════════════════════\n');