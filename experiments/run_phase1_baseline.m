%% run_phase1_baseline.m
% Phase 1: Baseline (T_hold=OFF)
%
% 목적: 기준선 성능 측정
% 변수: STA=[20,40,60], rho=[0.1,0.3,0.5]
% 총 9개 실험

clear; clc;
addpath(genpath(pwd));

%% 결과 폴더 생성
results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'phase1_baseline');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% 실험 설정
sta_list = [20, 40, 60];
rho_list = [0.1, 0.3, 0.5];
num_runs = 3;  % 반복 횟수

sim_time = 30.0;
mu_on = 0.05;  % 50ms
lambda = 50;

total_exp = length(sta_list) * length(rho_list) * num_runs;
exp_count = 0;
phase_results = [];

%% 실험 시작
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 1: Baseline (T_hold=OFF) - %d개 실험                  ║\n', total_exp);
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  STA: [20, 40, 60]                                          ║\n');
fprintf('║  rho: [0.1, 0.3, 0.5]                                       ║\n');
fprintf('║  sim_time: %.0fs, mu_on: %.0fms, lambda: %d pkt/s           ║\n', sim_time, mu_on*1000, lambda);
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

% rho별 mu_off 표시
fprintf('■ rho별 mu_off:\n');
for ri = 1:length(rho_list)
    rho = rho_list(ri);
    mu_off = mu_on * (1 - rho) / rho;
    fprintf('  rho=%.1f: mu_off=%.0fms\n', rho, mu_off*1000);
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
            
            exp_id = sprintf('B-%02d-R%d', (si-1)*length(rho_list) + ri, run);
            
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
            cfg.thold_enabled = false;
            cfg.thold_value = 0;
            cfg.verbose = 0;
            cfg.seed = 10000 + exp_count;
            
            % 실행
            exp_start = tic;
            results = run_simulation(cfg);
            elapsed = toc(exp_start);
            
            fprintf('완료 (%.1fs) - Delay: %.1fms, Collision: %.1f%%, Complete: %.1f%%\n', ...
                elapsed, results.delay.mean_ms, results.uora.collision_rate * 100, ...
                results.packets.completion_rate * 100);
            
            % 메타 정보
            results.exp_id = exp_id;
            results.phase = 1;
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
writetable(phase_table, fullfile(results_dir, 'summary', 'phase1_baseline.csv'));

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 1 완료                                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d개, 시간: %.1f분 (평균 %.1fs/실험)                  ║\n', ...
    exp_count, total_elapsed/60, total_elapsed/exp_count);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% 결과 요약 출력
fprintf('\n■ Baseline 결과 요약:\n');
fprintf('%-6s | %-6s | %-10s | %10s | %10s | %10s | %10s\n', ...
    'STA', 'rho', 'mu_off(ms)', 'Delay(ms)', 'Collision%', 'Complete%', 'Jain');
fprintf('%s\n', repmat('-', 1, 80));
for i = 1:height(phase_table)
    fprintf('%-6d | %-6.1f | %-10.0f | %10.2f | %10.1f | %10.1f | %10.3f\n', ...
        phase_table.num_stas(i), phase_table.rho(i), phase_table.mu_off_ms(i), ...
        phase_table.delay_mean_ms(i), phase_table.uora_collision_rate(i)*100, ...
        phase_table.completion_rate(i)*100, phase_table.jain_index(i));
end

fprintf('\n결과 저장: %s\n', fullfile(results_dir, 'summary', 'phase1_baseline.csv'));