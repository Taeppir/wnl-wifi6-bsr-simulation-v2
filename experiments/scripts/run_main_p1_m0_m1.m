%% run_main_m0_m1.m
% 본 실험: M0 vs M1(5) 비교
%
% 목적: 다양한 시나리오와 T_hold 값에서 M0과 M1(5)의 Trade-off 분석
%
% 실험 설계:
%   - 방법: Baseline, M0, M1(5)
%   - 시나리오: A (VoIP-like), B (Video-like), C (IoT-like)
%   - T_hold: 30, 50, 70ms
%   - 반복: 3회
%   - 총 runs: 9 (Baseline) + 54 (Methods) = 63
%
% 시각화 없음 (analyze_main_m0_m1.m에서 수행)

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║              본 실험: M0 vs M1(5) 비교 실험                       ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════════════

seeds = [1234, 5678, 9012];  % 3회 반복
sim_time = 20;  % 초

% 시나리오 정의
scenarios = struct();

% Scenario A: VoIP-like (느린 전송, 빈번한 ON/OFF)
scenarios.A.name = 'A';
scenarios.A.description = 'VoIP-like';
scenarios.A.lambda = 100;
scenarios.A.rho = 0.30;
scenarios.A.mu_off = 0.050;  % 50ms
scenarios.A.mu_on = scenarios.A.rho * scenarios.A.mu_off / (1 - scenarios.A.rho);  % 21ms

% Scenario B: Video-like (중간 전송, 긴 ON)
scenarios.B.name = 'B';
scenarios.B.description = 'Video-like';
scenarios.B.lambda = 200;
scenarios.B.rho = 0.50;
scenarios.B.mu_off = 0.050;  % 50ms
scenarios.B.mu_on = scenarios.B.rho * scenarios.B.mu_off / (1 - scenarios.B.rho);  % 33ms

% Scenario C: IoT-like (몰아서 전송, 드문 ON)
scenarios.C.name = 'C';
scenarios.C.description = 'IoT-like';
scenarios.C.lambda = 400;
scenarios.C.rho = 0.15;
scenarios.C.mu_off = 0.050;  % 50ms
scenarios.C.mu_on = scenarios.C.rho * scenarios.C.mu_off / (1 - scenarios.C.rho);  % 9ms

scenario_names = {'A', 'B', 'C'};

% T_hold 값들 (ms)
thold_values_ms = [30, 50, 70];

% 방법 정의: [method, max_phantom, label]
methods = {
    'M0',    Inf, 'M0';        % Phantom 무제한
    'M1',    5,   'M1(5)';     % Phantom 5회 제한
};

% 결과 저장 경로
output_dir = 'results/main_m0_m1_fixed';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 총 실험 수 계산
% Baseline: 3 시나리오 × 3 반복 = 9
% M0/M1(5): 3 시나리오 × 3 T_hold × 2 방법 × 3 반복 = 54
% 총: 63
num_seeds = length(seeds);
baseline_runs = length(scenario_names) * num_seeds;
method_runs = length(scenario_names) * length(thold_values_ms) * size(methods, 1) * num_seeds;
total_runs = baseline_runs + method_runs;

fprintf('[실험 설정]\n');
fprintf('  시나리오: A (VoIP), B (Video), C (IoT)\n');
fprintf('  T_hold: %s ms\n', mat2str(thold_values_ms));
fprintf('  방법: Baseline, M0, M1(5)\n');
fprintf('  반복: %d회 (seeds: %s)\n', num_seeds, mat2str(seeds));
fprintf('  총 runs: %d (Baseline %d + Methods %d)\n', total_runs, baseline_runs, method_runs);
fprintf('  Sim time: %d초\n', sim_time);
fprintf('  Output: %s/\n\n', output_dir);

% 시나리오 파라미터 출력
fprintf('[시나리오 파라미터]\n');
for i = 1:length(scenario_names)
    sc = scenarios.(scenario_names{i});
    fprintf('  %s (%s): λ=%d, ρ=%.2f, mu_on=%.1fms, mu_off=%.0fms\n', ...
        sc.name, sc.description, sc.lambda, sc.rho, sc.mu_on*1000, sc.mu_off*1000);
end
fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 실행
%  ═══════════════════════════════════════════════════════════════════════════

results = struct();
results.scenarios = scenarios;
results.thold_values_ms = thold_values_ms;
results.methods = methods;
results.seeds = seeds;
results.meta.sim_time = sim_time;
results.meta.timestamp = datetime('now');
results.meta.num_repeats = num_seeds;

run_count = 0;
total_start = tic;

%% ═══════════════════════════════════════════════════════════════════════════
%  Phase 1: Baseline 실행 (T_hold 없음)
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  Phase 1: Baseline 실행\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    for seed_idx = 1:num_seeds
        seed = seeds(seed_idx);
        run_count = run_count + 1;
        
        run_label = sprintf('%s_Baseline_s%d', sc_name, seed_idx);
        fprintf('[%3d/%d] %s ... ', run_count, total_runs, run_label);
        
        % Config 설정
        cfg = config_default();
        cfg.traffic_model = 'pareto_onoff';
        cfg.lambda = sc.lambda;
        cfg.rho = sc.rho;
        cfg.mu_on = sc.mu_on;
        cfg.mu_off = sc.mu_off;
        cfg.pareto_alpha = 1.5;
        cfg.simulation_time = sim_time;
        cfg.seed = seed;
        cfg.verbose = 0;
        cfg.thold_enabled = false;
        
        % 시뮬레이션 실행
        tic;
        r = run_simulation(cfg);
        elapsed = toc;
        
        % 메타데이터 추가
        r.scenario = sc_name;
        r.thold_ms = 0;
        r.method = 'Baseline';
        r.seed = seed;
        r.seed_idx = seed_idx;
        r.label = run_label;
        r.cfg = cfg;
        
        results.runs.(run_label) = r;
        fprintf('완료 (%.1fs)\n', elapsed);
    end
end

%% ═══════════════════════════════════════════════════════════════════════════
%  Phase 2: M0/M1(5) 실행
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  Phase 2: M0/M1(5) 실행\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    fprintf('\n[시나리오 %s: %s]\n', sc_name, sc.description);
    
    for th_idx = 1:length(thold_values_ms)
        thold_ms = thold_values_ms(th_idx);
        
        for m_idx = 1:size(methods, 1)
            method_type = methods{m_idx, 1};
            max_phantom = methods{m_idx, 2};
            method_label = methods{m_idx, 3};
            
            for seed_idx = 1:num_seeds
                seed = seeds(seed_idx);
                run_count = run_count + 1;
                
                % 실험 라벨
                run_label = sprintf('%s_T%d_%s_s%d', sc_name, thold_ms, method_label, seed_idx);
                
                fprintf('[%3d/%d] %s ... ', run_count, total_runs, run_label);
                
                % Config 설정
                cfg = config_default();
                cfg.traffic_model = 'pareto_onoff';
                cfg.lambda = sc.lambda;
                cfg.rho = sc.rho;
                cfg.mu_on = sc.mu_on;
                cfg.mu_off = sc.mu_off;
                cfg.pareto_alpha = 1.5;
                cfg.simulation_time = sim_time;
                cfg.seed = seed;
                cfg.verbose = 0;
                
                % T_hold 설정
                cfg.thold_enabled = true;
                cfg.thold_value = thold_ms / 1000;
                cfg.thold_method = method_type;
                cfg.thold_max_phantom = max_phantom;
                
                % 시뮬레이션 실행
                tic;
                r = run_simulation(cfg);
                elapsed = toc;
                
                % 메타데이터 추가
                r.scenario = sc_name;
                r.thold_ms = thold_ms;
                r.method = method_label;
                r.seed = seed;
                r.seed_idx = seed_idx;
                r.label = run_label;
                r.cfg = cfg;
                
                % 결과 저장 (필드명으로)
                field_name = strrep(run_label, '(', '_');
                field_name = strrep(field_name, ')', '');
                results.runs.(field_name) = r;
                
                fprintf('완료 (%.1fs)\n', elapsed);
                
                % 중간 저장 (20개마다)
                if mod(run_count, 20) == 0
                    save(fullfile(output_dir, 'results_partial.mat'), 'results');
                    fprintf('    [중간 저장 완료]\n');
                end
            end
        end
    end
end

total_elapsed = toc(total_start);
fprintf('\n총 실행 시간: %.1f분\n', total_elapsed / 60);

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 저장
%  ═══════════════════════════════════════════════════════════════════════════

output_file = fullfile(output_dir, 'results.mat');
save(output_file, 'results');
fprintf('결과 저장: %s\n', output_file);

% 부분 저장 파일 삭제
partial_file = fullfile(output_dir, 'results_partial.mat');
if exist(partial_file, 'file')
    delete(partial_file);
end

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 요약 출력 (반복 평균)
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                            결과 요약 (3회 반복 평균 ± std)                                                         ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

% 시나리오별 요약
for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    fprintf('[시나리오 %s: %s]\n', sc_name, sc.description);
    fprintf('┌──────────┬──────────┬─────────────────┬─────────────────┬─────────────────┬─────────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Mean Delay      │ P90 Delay       │ Hit Rate        │ Phantoms        │\n');
    fprintf('├──────────┼──────────┼─────────────────┼─────────────────┼─────────────────┼─────────────────┤\n');
    
    % Baseline 먼저
    delays = []; p90s = [];
    for seed_idx = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc_name, seed_idx);
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            delays(end+1) = r.delay.mean_ms;
            p90s(end+1) = r.delay.p90_ms;
        end
    end
    if ~isempty(delays)
        fprintf('│ %4s     │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %8s        │ %8s        │\n', ...
            'N/A', 'Baseline', mean(delays), std(delays), mean(p90s), std(p90s), 'N/A', 'N/A');
    end
    
    % M0, M1(5)
    for th_idx = 1:length(thold_values_ms)
        thold_ms = thold_values_ms(th_idx);
        
        for m_idx = 1:size(methods, 1)
            method_label = methods{m_idx, 3};
            
            % 3회 반복 결과 수집
            delays = [];
            p90s = [];
            hit_rates = [];
            phantoms_arr = [];
            
            for seed_idx = 1:num_seeds
                field_name = sprintf('%s_T%d_%s_s%d', sc_name, thold_ms, method_label, seed_idx);
                field_name = strrep(field_name, '(', '_');
                field_name = strrep(field_name, ')', '');
                
                if isfield(results.runs, field_name)
                    r = results.runs.(field_name);
                    delays(end+1) = r.delay.mean_ms;
                    p90s(end+1) = r.delay.p90_ms;
                    
                    if isfield(r, 'thold') && isfield(r.thold, 'hit_rate')
                        hit_rates(end+1) = r.thold.hit_rate * 100;
                        phantoms_arr(end+1) = r.thold.phantoms;
                    else
                        hit_rates(end+1) = 0;
                        phantoms_arr(end+1) = 0;
                    end
                end
            end
            
            if ~isempty(delays)
                fprintf('│ %4dms   │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %5.1f%% ± %4.1f%% │ %6.0f ± %5.0f  │\n', ...
                    thold_ms, method_label, ...
                    mean(delays), std(delays), ...
                    mean(p90s), std(p90s), ...
                    mean(hit_rates), std(hit_rates), ...
                    mean(phantoms_arr), std(phantoms_arr));
            end
        end
    end
    fprintf('└──────────┴──────────┴─────────────────┴─────────────────┴─────────────────┴─────────────────┘\n\n');
end

% Baseline 대비 변화율 요약
fprintf('[Baseline 대비 평균 지연 개선율 (평균)]\n');
fprintf('┌──────────┬──────────┬─────────────────────┬─────────────────────┐\n');
fprintf('│ Scenario │ T_hold   │ M0 개선율           │ M1(5) 개선율        │\n');
fprintf('├──────────┼──────────┼─────────────────────┼─────────────────────┤\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    
    % Baseline 지연 평균
    base_delays = [];
    for seed_idx = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc_name, seed_idx);
        if isfield(results.runs, field_name)
            base_delays(end+1) = results.runs.(field_name).delay.mean_ms;
        end
    end
    base_delay = mean(base_delays);
    
    for th_idx = 1:length(thold_values_ms)
        thold_ms = thold_values_ms(th_idx);
        
        % M0 개선율
        m0_delays = [];
        for seed_idx = 1:num_seeds
            field_name = sprintf('%s_T%d_M0_s%d', sc_name, thold_ms, seed_idx);
            if isfield(results.runs, field_name)
                m0_delays(end+1) = results.runs.(field_name).delay.mean_ms;
            end
        end
        m0_change = -(mean(m0_delays) - base_delay) / base_delay * 100;
        
        % M1(5) 개선율
        m1_delays = [];
        for seed_idx = 1:num_seeds
            field_name = sprintf('%s_T%d_M1_5__s%d', sc_name, thold_ms, seed_idx);
            if isfield(results.runs, field_name)
                m1_delays(end+1) = results.runs.(field_name).delay.mean_ms;
            end
        end
        m1_change = -(mean(m1_delays) - base_delay) / base_delay * 100;
        
        fprintf('│ %s        │ %4dms   │ %+6.1f%% (%5.1f→%5.1fms) │ %+6.1f%% (%5.1f→%5.1fms) │\n', ...
            sc_name, thold_ms, m0_change, base_delay, mean(m0_delays), ...
            m1_change, base_delay, mean(m1_delays));
    end
end
fprintf('└──────────┴──────────┴─────────────────────┴─────────────────────┘\n');

fprintf('\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  본 실험 완료!\n');
fprintf('  결과 파일: %s\n', output_file);
fprintf('  시각화: analyze_main_m0_m1 실행\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');