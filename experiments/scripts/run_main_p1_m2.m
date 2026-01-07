%% run_main_m2.m
% M2 기법 실험
%
% 목적: M2 기법의 성능 측정 (M0/M1과 별도 실험)
%
% 실험 설계:
%   - 방법: M2 (Baseline은 run_main_m0_m1에서 이미 실행)
%   - 시나리오: A (VoIP-like), B (Video-like), C (IoT-like)
%   - T_hold: 30, 50, 70ms
%   - 반복: 3회
%   - 총 runs: 3 시나리오 × 3 T_hold × 3 반복 = 27

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    M2 기법 실험                                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════════════

seeds = [1234, 5678, 9012, 3456, 7890, 1111, 2222, 3333, 4444, 5555];  % 3회 반복
sim_time = 30;  % 초

% 시나리오 정의 (run_main_m0_m1과 동일)
scenarios = struct();

% Scenario A: VoIP-like
scenarios.A.name = 'A';
scenarios.A.description = 'VoIP-like';
scenarios.A.lambda = 100;
scenarios.A.rho = 0.30;
scenarios.A.mu_off = 0.050;
scenarios.A.mu_on = scenarios.A.rho * scenarios.A.mu_off / (1 - scenarios.A.rho);

% Scenario B: Video-like
scenarios.B.name = 'B';
scenarios.B.description = 'Video-like';
scenarios.B.lambda = 200;
scenarios.B.rho = 0.50;
scenarios.B.mu_off = 0.050;
scenarios.B.mu_on = scenarios.B.rho * scenarios.B.mu_off / (1 - scenarios.B.rho);

% Scenario C: IoT-like
scenarios.C.name = 'C';
scenarios.C.description = 'IoT-like';
scenarios.C.lambda = 400;
scenarios.C.rho = 0.15;
scenarios.C.mu_off = 0.050;
scenarios.C.mu_on = scenarios.C.rho * scenarios.C.mu_off / (1 - scenarios.C.rho);

scenario_names = {'A', 'B', 'C'};

% T_hold 값들 (ms)
thold_values_ms = [30, 50, 70];

% 결과 저장 경로
output_dir = 'results/main_m2_final';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 총 실험 수 계산
num_seeds = length(seeds);
total_runs = length(scenario_names) * length(thold_values_ms) * num_seeds;

fprintf('[실험 설정]\n');
fprintf('  시나리오: A (VoIP), B (Video), C (IoT)\n');
fprintf('  T_hold: %s ms\n', mat2str(thold_values_ms));
fprintf('  방법: M2\n');
fprintf('  반복: %d회 (seeds: %s)\n', num_seeds, mat2str(seeds));
fprintf('  총 runs: %d\n', total_runs);
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
results.seeds = seeds;
results.meta.sim_time = sim_time;
results.meta.timestamp = datetime('now');
results.meta.method = 'M2';

run_count = 0;
total_start = tic;

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  M2 실험 시작\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    fprintf('\n[시나리오 %s: %s]\n', sc_name, sc.description);
    
    for th_idx = 1:length(thold_values_ms)
        thold_ms = thold_values_ms(th_idx);
        
        for seed_idx = 1:num_seeds
            seed = seeds(seed_idx);
            run_count = run_count + 1;
            
            run_label = sprintf('%s_T%d_M2_s%d', sc_name, thold_ms, seed_idx);
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
            
            % T_hold 설정 - M2
            cfg.thold_enabled = true;
            cfg.thold_value = thold_ms / 1000;
            cfg.thold_method = 'M2';
            
            % 시뮬레이션 실행
            tic;
            r = run_simulation(cfg);
            elapsed = toc;
            
            % 메타데이터 추가
            r.scenario = sc_name;
            r.thold_ms = thold_ms;
            r.method = 'M2';
            r.seed = seed;
            r.seed_idx = seed_idx;
            r.label = run_label;
            r.cfg = cfg;
            
            results.runs.(run_label) = r;
            fprintf('완료 (%.1fs)\n', elapsed);
            
            % 중간 저장 (10개마다)
            if mod(run_count, 10) == 0
                save(fullfile(output_dir, 'results_partial.mat'), 'results');
                fprintf('    [중간 저장 완료]\n');
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
%  결과 요약 출력
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                          M2 결과 요약 (3회 반복 평균 ± std)                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    fprintf('[시나리오 %s: %s]\n', sc_name, sc.description);
    fprintf('┌──────────┬─────────────────┬─────────────────┬─────────────────┬─────────────────┐\n');
    fprintf('│ T_hold   │ Mean Delay      │ P90 Delay       │ Hit Rate        │ Phantoms        │\n');
    fprintf('├──────────┼─────────────────┼─────────────────┼─────────────────┼─────────────────┤\n');
    
    for th_idx = 1:length(thold_values_ms)
        thold_ms = thold_values_ms(th_idx);
        
        % 3회 반복 결과 수집
        delays = [];
        p90s = [];
        hit_rates = [];
        phantoms_arr = [];
        
        for seed_idx = 1:num_seeds
            field_name = sprintf('%s_T%d_M2_s%d', sc_name, thold_ms, seed_idx);
            
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
            fprintf('│ %4dms   │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %5.1f%% ± %4.1f%% │ %6.0f ± %5.0f  │\n', ...
                thold_ms, ...
                mean(delays), std(delays), ...
                mean(p90s), std(p90s), ...
                mean(hit_rates), std(hit_rates), ...
                mean(phantoms_arr), std(phantoms_arr));
        end
    end
    fprintf('└──────────┴─────────────────┴─────────────────┴─────────────────┴─────────────────┘\n\n');
end

fprintf('\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  M2 실험 완료!\n');
fprintf('  결과 파일: %s\n', output_file);
fprintf('  M0/M1 결과와 비교: analyze_all_methods 실행\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');