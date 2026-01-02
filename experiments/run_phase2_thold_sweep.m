%% run_phase2_thold_sweep.m
% Phase 2: T_hold Sweep (rho=0.5 고정)
%
% 목적: 최적 T_hold 값 탐색
% 변수: STA=[20,40,60], T_hold=[30,50,70]ms
% rho=0.5 고정 (mu_off=50ms)
% 총 9개 실험

clear; clc;
addpath(genpath(pwd));

%% 결과 폴더 생성
results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'phase2_thold_sweep');
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% 실험 설정
sta_list = [20];
thold_list = [0, 30];  % ms
num_runs = 1;  % 반복 횟수

rho = 0.5;  % 고정
sim_time = 15.0;
mu_on = 0.05;  % 50ms
mu_off = mu_on * (1 - rho) / rho;  % 50ms
lambda = 50;

total_exp = length(sta_list) * length(thold_list) * num_runs;
exp_count = 0;
phase_results = [];

%% 실험 시작
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 2: T_hold Sweep (rho=0.5) - %d개 실험                 ║\n', total_exp);
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  STA: [20, 40, 60]                                          ║\n');
fprintf('║  T_hold: [30, 50, 70]ms                                     ║\n');
fprintf('║  rho: 0.5 (mu_off=50ms)                                     ║\n');
fprintf('║  Coverage: [60%%, 100%%, 140%%]                               ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

total_start = tic;

for si = 1:length(sta_list)
    for ti = 1:length(thold_list)
        for run = 1:num_runs
            exp_count = exp_count + 1;
            
            sta = sta_list(si);
            thold_ms = thold_list(ti);
            coverage = thold_ms / (mu_off * 1000) * 100;
            
            exp_id = sprintf('T-%02d-R%d', (si-1)*length(thold_list) + ti, run);
            
            fprintf('[%d/%d] %s: STA=%d, T_hold=%dms, run=%d... ', ...
                exp_count, total_exp, exp_id, sta, thold_ms, run);
            
            % 설정
            cfg = config_default();
            cfg.simulation_time = sim_time;
            cfg.warmup_time = 0.0;
            cfg.num_stas = sta;
            cfg.rho = rho;
            cfg.mu_on = mu_on;
            cfg.mu_off = mu_off;
            cfg.lambda = lambda;
            cfg.thold_enabled = true;
            cfg.thold_value = thold_ms / 1000;
            cfg.verbose = 0;
            cfg.seed = 20000 + exp_count;
            
            % 실행
            exp_start = tic;
            results = run_simulation(cfg);
            elapsed = toc(exp_start);
            
            fprintf('완료 (%.1fs) - Delay: %.1fms, HitRate: %.1f%%\n', ...
                elapsed, results.delay.mean_ms, results.thold.hit_rate * 100);
            
            % 메타 정보
            results.exp_id = exp_id;
            results.phase = 2;
            results.run = run;
            results.config = cfg;
            
            % 저장
            filename = sprintf('%s_STA%d_thold%d_run%d.mat', exp_id, sta, thold_ms, run);
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
writetable(phase_table, fullfile(results_dir, 'summary', 'phase2_thold_sweep.csv'));

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 2 완료                                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d개, 시간: %.1f분 (평균 %.1fs/실험)                  ║\n', ...
    exp_count, total_elapsed/60, total_elapsed/exp_count);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% 결과 요약 출력
fprintf('\n■ T_hold Sweep 결과 요약:\n');
fprintf('%-6s | %-8s | %10s | %10s | %8s | %10s | %10s\n', ...
    'STA', 'T_hold', 'Delay(ms)', 'Complete%', 'HitRate%', 'Phantom', 'Expiration');
fprintf('%s\n', repmat('-', 1, 85));
for i = 1:height(phase_table)
    fprintf('%-6d | %6dms | %10.2f | %10.1f | %8.1f | %10d | %10d\n', ...
        phase_table.num_stas(i), phase_table.thold_ms(i), ...
        phase_table.delay_mean_ms(i), phase_table.completion_rate(i)*100, ...
        phase_table.thold_hit_rate(i)*100, phase_table.thold_phantom_count(i), ...
        phase_table.thold_expirations(i));
end

%% Baseline과 비교 (Phase 1 로드)
fprintf('\n■ Baseline 대비 개선율 (rho=0.5):\n');
phase1_file = fullfile(results_dir, 'summary', 'phase1_baseline.csv');
if exist(phase1_file, 'file')
    baseline = readtable(phase1_file);
    
    fprintf('%-6s | %-8s | %12s | %12s | %12s\n', ...
        'STA', 'T_hold', 'Delay개선%', 'Complete변화', 'Collision변화');
    fprintf('%s\n', repmat('-', 1, 65));
    
    for si = 1:length(sta_list)
        sta = sta_list(si);
        
        % Baseline 찾기
        base_idx = baseline.num_stas == sta & abs(baseline.rho - 0.5) < 0.01;
        if any(base_idx)
            base_delay = baseline.delay_mean_ms(base_idx);
            base_complete = baseline.completion_rate(base_idx);
            base_collision = baseline.uora_collision_rate(base_idx);
            
            for ti = 1:length(thold_list)
                thold_ms = thold_list(ti);
                
                % T_hold 결과 찾기
                thold_idx = phase_table.num_stas == sta & phase_table.thold_ms == thold_ms;
                if any(thold_idx)
                    thold_delay = phase_table.delay_mean_ms(thold_idx);
                    thold_complete = phase_table.completion_rate(thold_idx);
                    thold_collision = phase_table.uora_collision_rate(thold_idx);
                    
                    delay_improve = (base_delay - thold_delay) / base_delay * 100;
                    complete_change = (thold_complete - base_complete) * 100;
                    collision_change = (thold_collision - base_collision) * 100;
                    
                    fprintf('%-6d | %6dms | %+10.1f%% | %+10.1f%% | %+10.1f%%\n', ...
                        sta, thold_ms, delay_improve, complete_change, collision_change);
                end
            end
        end
    end
else
    fprintf('(Phase 1 결과 없음 - 먼저 run_phase1_baseline.m 실행)\n');
end

fprintf('\n결과 저장: %s\n', fullfile(results_dir, 'summary', 'phase2_thold_sweep.csv'));