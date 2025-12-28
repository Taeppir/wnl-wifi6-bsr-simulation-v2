%% run_phase3_rho_sweep.m
% Phase 3: rho Sweep (최적 T_hold 적용)
%
% 목적: rho별 T_hold 효과 검증
% 변수: STA=[20,40,60], rho=[0.1,0.3,0.5]
% T_hold: Phase 2에서 결정 (기본값 50ms)
% 총 9개 실험

clear; clc;
addpath(genpath(pwd));

%% 결과 폴더 생성
results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'phase3_rho_sweep');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% 실험 설정
sta_list = [20, 40, 60];
rho_list = [0.1, 0.3, 0.5];
num_runs = 3;  % 반복 횟수

% ★ Phase 2 결과 보고 최적 T_hold 설정
optimal_thold_ms = 50;  % 기본값, Phase 2 결과 보고 조정

sim_time = 30.0;
mu_on = 0.05;  % 50ms
lambda = 50;

total_exp = length(sta_list) * length(rho_list) * num_runs;
exp_count = 0;
phase_results = [];

%% 실험 시작
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 3: rho Sweep (T_hold=%dms) - %d개 실험                ║\n', optimal_thold_ms, total_exp);
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  STA: [20, 40, 60]                                          ║\n');
fprintf('║  rho: [0.1, 0.3, 0.5]                                       ║\n');
fprintf('║  T_hold: %dms (Phase 2에서 결정)                             ║\n', optimal_thold_ms);
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

% rho별 mu_off와 coverage 미리 계산
fprintf('■ rho별 T_hold 커버리지:\n');
for ri = 1:length(rho_list)
    rho = rho_list(ri);
    mu_off = mu_on * (1 - rho) / rho;
    coverage = optimal_thold_ms / (mu_off * 1000) * 100;
    fprintf('  rho=%.1f: mu_off=%.0fms, coverage=%.0f%%\n', rho, mu_off*1000, coverage);
end
fprintf('\n');

total_start = tic;

for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        for run = 1:num_runs
            exp_count = exp_count + 1;
            
            sta = sta_list(si);
            rho = rho_list(ri);
            mu_off = mu_on * (1 - rho) / rho;
            coverage = optimal_thold_ms / (mu_off * 1000) * 100;
            
            exp_id = sprintf('R-%02d-R%d', (si-1)*length(rho_list) + ri, run);
            
            fprintf('[%d/%d] %s: STA=%d, rho=%.1f, run=%d... ', ...
                exp_count, total_exp, exp_id, sta, rho, run);
            
            % 설정
            cfg = config_default();
            cfg.simulation_time = sim_time;
            cfg.warmup_time = 2.0;
            cfg.num_stas = sta;
            cfg.rho = rho;
            cfg.mu_on = mu_on;
            cfg.mu_off = mu_off;
            cfg.lambda = lambda;
            cfg.thold_enabled = true;
            cfg.thold_value = optimal_thold_ms / 1000;
            cfg.verbose = 0;
            cfg.seed = 30000 + exp_count;
            
            % 실행
            exp_start = tic;
            results = run_simulation(cfg);
            elapsed = toc(exp_start);
            
            fprintf('완료 (%.1fs) - Delay: %.1fms, HitRate: %.1f%%\n', ...
                elapsed, results.delay.mean_ms, results.thold.hit_rate * 100);
            
            % 메타 정보
            results.exp_id = exp_id;
            results.phase = 3;
            results.run = run;
            results.config = cfg;
            
            % 저장
            filename = sprintf('%s_STA%d_rho%.1f_run%d.mat', exp_id, sta, rho, run);
            save(fullfile(phase_dir, filename), 'results');
            
            % 요약
            summary = summarize_results(results, cfg);
            summary.run = run;
            phase_results = [phase_results; summary];
        end
    end
end

%% 완료
total_elapsed = toc(total_start);

% CSV 저장
phase_table = struct2table(phase_results);
writetable(phase_table, fullfile(results_dir, 'summary', 'phase3_rho_sweep.csv'));

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 3 완료                                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d개, 시간: %.1f분 (평균 %.1fs/실험)                  ║\n', ...
    exp_count, total_elapsed/60, total_elapsed/exp_count);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% 결과 요약 및 Baseline 비교
fprintf('\n■ Phase 3 결과 vs Baseline:\n');
phase1_file = fullfile(results_dir, 'summary', 'phase1_baseline.csv');

if exist(phase1_file, 'file')
    baseline = readtable(phase1_file);
    
    fprintf('%-6s | %-6s | %-10s | %10s | %10s | %10s | %10s\n', ...
        'STA', 'rho', 'Coverage', 'BaseDelay', 'T_holdDelay', 'Improve%', 'Complete%');
    fprintf('%s\n', repmat('-', 1, 85));
    
    for si = 1:length(sta_list)
        for ri = 1:length(rho_list)
            sta = sta_list(si);
            rho = rho_list(ri);
            mu_off = mu_on * (1 - rho) / rho;
            coverage = optimal_thold_ms / (mu_off * 1000) * 100;
            
            % Baseline
            base_idx = baseline.num_stas == sta & abs(baseline.rho - rho) < 0.01;
            % T_hold
            thold_idx = phase_table.num_stas == sta & abs(phase_table.rho - rho) < 0.01;
            
            if any(base_idx) && any(thold_idx)
                base_delay = baseline.delay_mean_ms(base_idx);
                thold_delay = phase_table.delay_mean_ms(thold_idx);
                thold_complete = phase_table.completion_rate(thold_idx) * 100;
                
                improve = (base_delay - thold_delay) / base_delay * 100;
                
                fprintf('%-6d | %-6.1f | %8.0f%% | %10.1f | %10.1f | %+9.1f%% | %9.1f%%\n', ...
                    sta, rho, coverage, base_delay, thold_delay, improve, thold_complete);
            end
        end
    end
else
    fprintf('(Phase 1 결과 없음)\n');
end

%% T_hold 상세 지표
fprintf('\n■ T_hold 상세 지표:\n');
fprintf('%-6s | %-6s | %10s | %10s | %10s | %10s\n', ...
    'STA', 'rho', 'Activations', 'Hits', 'Expirations', 'Phantom');
fprintf('%s\n', repmat('-', 1, 70));

for i = 1:height(phase_table)
    fprintf('%-6d | %-6.1f | %10d | %10d | %10d | %10d\n', ...
        phase_table.num_stas(i), phase_table.rho(i), ...
        phase_table.thold_activations(i), ...
        phase_table.thold_hits(i), ...
        phase_table.thold_expirations(i), ...
        phase_table.thold_phantom_count(i));
end

%% 공정성 분석
fprintf('\n■ 공정성 분석:\n');
fprintf('%-6s | %-6s | %10s | %10s | %12s\n', ...
    'STA', 'rho', 'Jain Index', 'CoV', 'MinMax Ratio');
fprintf('%s\n', repmat('-', 1, 55));

for i = 1:height(phase_table)
    fprintf('%-6d | %-6.1f | %10.4f | %10.4f | %12.4f\n', ...
        phase_table.num_stas(i), phase_table.rho(i), ...
        phase_table.jain_index(i), phase_table.cov(i), ...
        phase_table.min_max_ratio(i));
end

fprintf('\n결과 저장: %s\n', fullfile(results_dir, 'summary', 'phase3_rho_sweep.csv'));