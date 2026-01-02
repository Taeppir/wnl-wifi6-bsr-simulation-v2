%% run_thold_comparison.m
% T_hold 조건별 비교 실험
%
% 목적: Baseline vs T_hold 값별 성능 비교
% 조건: Baseline(OFF), T_hold=0ms, 30ms, 50ms
% 고정: STA=20, rho=0.5

clear; clc;
addpath(genpath(pwd));

%% 결과 폴더 생성
results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'thold_comparison');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% ═══════════════════════════════════════════════════════════════
%  실험 설정 (여기서 수정)
%  ═══════════════════════════════════════════════════════════════

% 실험 조건
conditions = {
    'Baseline', false, 0;      % T_hold OFF
    'T0',       true,  0;      % T_hold=0ms (활성화했지만 0)
    'T30',      true,  30;     % T_hold=30ms
    'T50',      true,  50;     % T_hold=50ms
};
% 각 행: {이름, thold_enabled, thold_ms}

% 고정 파라미터
num_stas = 20;
rho = 0.5;
sim_time = 30.0;      % 시뮬레이션 시간 (초)
mu_on = 0.05;         % 50ms
mu_off = mu_on * (1 - rho) / rho;  % 50ms
lambda = 50;          % pkt/s
num_runs = 2;         % 반복 횟수

%% ═══════════════════════════════════════════════════════════════

num_conditions = size(conditions, 1);
total_exp = num_conditions * num_runs;
exp_count = 0;
all_results = [];

%% 실험 시작
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  T_hold Comparison - %d개 실험                               ║\n', total_exp);
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  조건: Baseline, T_hold=0ms, 30ms, 50ms                     ║\n');
fprintf('║  STA: %d, rho: %.1f, sim_time: %.0fs                        ║\n', num_stas, rho, sim_time);
fprintf('║  mu_on: %.0fms, mu_off: %.0fms, lambda: %d pkt/s            ║\n', mu_on*1000, mu_off*1000, lambda);
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

total_start = tic;

for ci = 1:num_conditions
    cond_name = conditions{ci, 1};
    thold_enabled = conditions{ci, 2};
    thold_ms = conditions{ci, 3};
    
    for run = 1:num_runs
        exp_count = exp_count + 1;
        
        exp_id = sprintf('%s-R%d', cond_name, run);
        
        fprintf('[%d/%d] %s: thold_enabled=%d, T_hold=%dms, run=%d... ', ...
            exp_count, total_exp, exp_id, thold_enabled, thold_ms, run);
        
        % 설정
        cfg = config_default();
        cfg.simulation_time = sim_time;
        cfg.warmup_time = 2.0;
        cfg.num_stas = num_stas;
        cfg.rho = rho;
        cfg.mu_on = mu_on;
        cfg.mu_off = mu_off;
        cfg.lambda = lambda;
        cfg.thold_enabled = thold_enabled;
        cfg.thold_value = thold_ms / 1000;
        cfg.verbose = 0;
        cfg.seed = 30000 + exp_count;
        
        % 실행
        exp_start = tic;
        results = run_simulation(cfg);
        elapsed = toc(exp_start);
        
        % 출력
        if thold_enabled && isfield(results, 'thold')
            fprintf('완료 (%.1fs) - Delay: %.1fms, HitRate: %.1f%%, Complete: %.1f%%\n', ...
                elapsed, results.delay.mean_ms, results.thold.hit_rate * 100, ...
                results.packets.completion_rate * 100);
        else
            fprintf('완료 (%.1fs) - Delay: %.1fms, Collision: %.1f%%, Complete: %.1f%%\n', ...
                elapsed, results.delay.mean_ms, results.uora.collision_rate * 100, ...
                results.packets.completion_rate * 100);
        end
        
        % 메타 정보
        results.exp_id = exp_id;
        results.phase = 0;  % comparison experiment
        results.condition = cond_name;
        results.run = run;
        results.config = cfg;
        
        % 저장
        filename = sprintf('%s_run%d.mat', cond_name, run);
        save(fullfile(phase_dir, filename), 'results');
        
        % 요약
        summary = summarize_results(results, cfg);
        summary.condition = cond_name;
        summary.thold_enabled = thold_enabled;
        summary.run = run;
        all_results = [all_results; summary];
    end
end

%% 완료
total_elapsed = toc(total_start);

% CSV 저장
results_table = struct2table(all_results);
writetable(results_table, fullfile(results_dir, 'summary', 'thold_comparison.csv'));

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  실험 완료                                                   ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d개, 시간: %.1f분 (평균 %.1fs/실험)                  ║\n', ...
    exp_count, total_elapsed/60, total_elapsed/exp_count);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% 결과 요약 출력
fprintf('\n■ T_hold 비교 결과 요약:\n');
fprintf('%-10s | %10s | %10s | %10s | %8s | %8s | %8s | %8s\n', ...
    'Condition', 'Delay(ms)', 'DelayStd', 'Complete%', 'HitRate%', 'Phantom', 'Exp_Empty', 'Exp_Data');
fprintf('%s\n', repmat('-', 1, 100));

for i = 1:height(results_table)
    hit_rate = 0;
    phantom = 0;
    exp_empty = 0;
    exp_data = 0;
    
    if results_table.thold_enabled(i)
        hit_rate = results_table.thold_hit_rate(i) * 100;
        phantom = results_table.thold_phantom_count(i);
        if ismember('thold_expirations_empty', results_table.Properties.VariableNames)
            exp_empty = results_table.thold_expirations_empty(i);
        end
        if ismember('thold_expirations_with_data', results_table.Properties.VariableNames)
            exp_data = results_table.thold_expirations_with_data(i);
        end
    end
    
    fprintf('%-10s | %10.2f | %10.2f | %10.1f | %8.1f | %8d | %8d | %8d\n', ...
        results_table.condition{i}, ...
        results_table.delay_mean_ms(i), ...
        results_table.delay_std_ms(i), ...
        results_table.completion_rate(i) * 100, ...
        hit_rate, phantom, exp_empty, exp_data);
end

%% 조건별 평균 출력
fprintf('\n■ 조건별 평균 (runs 평균):\n');
fprintf('%-10s | %10s | %10s | %10s | %10s\n', ...
    'Condition', 'Delay(ms)', 'Complete%', 'Throughput', 'Collision%');
fprintf('%s\n', repmat('-', 1, 60));

for ci = 1:num_conditions
    cond_name = conditions{ci, 1};
    idx = strcmp(results_table.condition, cond_name);
    
    mean_delay = mean(results_table.delay_mean_ms(idx));
    mean_complete = mean(results_table.completion_rate(idx)) * 100;
    mean_throughput = mean(results_table.throughput_mbps(idx));
    mean_collision = mean(results_table.uora_collision_rate(idx)) * 100;
    
    fprintf('%-10s | %10.2f | %10.1f | %10.2f | %10.1f\n', ...
        cond_name, mean_delay, mean_complete, mean_throughput, mean_collision);
end

fprintf('\n결과 저장: %s\n', fullfile(results_dir, 'summary', 'thold_comparison.csv'));
fprintf('분석 스크립트: analyze_thold_comparison.m\n');