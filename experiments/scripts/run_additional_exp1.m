%% run_additional_exp1.m
% 추가 실험 1: 시스템 파라미터 변화 (RA-RU 수, STA 수)
%
% 목적: 시스템 구성 변화에 따른 M2 기법 효과 분석
%
% 실험 설계:
%   - 시나리오: D-1, D-2, D-3, D-4
%   - 방법: Baseline, M2
%   - 트래픽: ρ=0.5, λ=100, μ_on=50ms, μ_off=50ms
%   - T_hold: 50ms (M2만)
%   - 반복: 3회
%   - 총 runs: 4 시나리오 × 2 방법 × 3 반복 = 24

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║         추가 실험 1: 시스템 파라미터 변화 (RA-RU, STA)            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════════════

seeds = [1234, 5678, 9012];
sim_time = 20;

% 공통 트래픽 파라미터
traffic = struct();
traffic.rho = 0.5;
traffic.lambda = 100;
traffic.mu_off = 0.050;  % 50ms
traffic.mu_on = traffic.rho * traffic.mu_off / (1 - traffic.rho);  % 50ms

% T_hold 설정
thold_ms = 50;

% 시나리오 정의: [name, RA-RU, SA-RU, STA, 전체부하, 용량대비]
scenarios = struct();

scenarios.D1.name = 'D-1';
scenarios.D1.description = 'Baseline config';
scenarios.D1.num_ra_ru = 1;
scenarios.D1.num_sa_ru = 8;
scenarios.D1.num_sta = 20;
scenarios.D1.load_pps = 1000;
scenarios.D1.capacity_ratio = 35;

scenarios.D2.name = 'D-2';
scenarios.D2.description = 'More RA-RU';
scenarios.D2.num_ra_ru = 2;
scenarios.D2.num_sa_ru = 7;
scenarios.D2.num_sta = 20;
scenarios.D2.load_pps = 1000;
scenarios.D2.capacity_ratio = 40;

scenarios.D3.name = 'D-3';
scenarios.D3.description = 'More STA';
scenarios.D3.num_ra_ru = 1;
scenarios.D3.num_sa_ru = 8;
scenarios.D3.num_sta = 50;
scenarios.D3.load_pps = 2500;
scenarios.D3.capacity_ratio = 87;

scenarios.D4.name = 'D-4';
scenarios.D4.description = 'More RA-RU + STA';
scenarios.D4.num_ra_ru = 2;
scenarios.D4.num_sa_ru = 7;
scenarios.D4.num_sta = 50;
scenarios.D4.load_pps = 2500;
scenarios.D4.capacity_ratio = 99;

scenario_names = {'D1', 'D2', 'D3', 'D4'};

% 방법
methods = {'Baseline', 'M2'};

% 결과 저장 경로
output_dir = 'results/additional_exp1';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 총 실험 수
num_seeds = length(seeds);
total_runs = length(scenario_names) * length(methods) * num_seeds;

fprintf('[실험 설정]\n');
fprintf('  시나리오: D-1, D-2, D-3, D-4\n');
fprintf('  방법: Baseline, M2\n');
fprintf('  T_hold: %dms (M2)\n', thold_ms);
fprintf('  트래픽: ρ=%.1f, λ=%d, μ_on=%.0fms, μ_off=%.0fms\n', ...
    traffic.rho, traffic.lambda, traffic.mu_on*1000, traffic.mu_off*1000);
fprintf('  반복: %d회 (seeds: %s)\n', num_seeds, mat2str(seeds));
fprintf('  총 runs: %d\n', total_runs);
fprintf('  Sim time: %d초\n', sim_time);
fprintf('  Output: %s/\n\n', output_dir);

% 시나리오 파라미터 출력
fprintf('[시나리오 파라미터]\n');
fprintf('┌────────┬────────┬────────┬───────┬────────────┬──────────┐\n');
fprintf('│ 시나리오 │ RA-RU  │ SA-RU  │  STA  │ 전체 부하   │ 용량 대비 │\n');
fprintf('├────────┼────────┼────────┼───────┼────────────┼──────────┤\n');
for i = 1:length(scenario_names)
    sc = scenarios.(scenario_names{i});
    fprintf('│  %s   │   %d    │   %d    │  %2d   │ %4d pkt/s │   %2d%%    │\n', ...
        sc.name, sc.num_ra_ru, sc.num_sa_ru, sc.num_sta, sc.load_pps, sc.capacity_ratio);
end
fprintf('└────────┴────────┴────────┴───────┴────────────┴──────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 실행
%  ═══════════════════════════════════════════════════════════════════════════

results = struct();
results.scenarios = scenarios;
results.traffic = traffic;
results.thold_ms = thold_ms;
results.methods = methods;
results.seeds = seeds;
results.meta.sim_time = sim_time;
results.meta.timestamp = datetime('now');

run_count = 0;
total_start = tic;

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  실험 시작\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

for sc_idx = 1:length(scenario_names)
    sc_key = scenario_names{sc_idx};
    sc = scenarios.(sc_key);
    
    fprintf('\n[시나리오 %s: %s]\n', sc.name, sc.description);
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        
        for seed_idx = 1:num_seeds
            seed = seeds(seed_idx);
            run_count = run_count + 1;
            
            run_label = sprintf('%s_%s_s%d', sc.name, method, seed_idx);
            run_label = strrep(run_label, '-', '_');
            fprintf('[%3d/%d] %s ... ', run_count, total_runs, run_label);
            
            % Config 설정
            cfg = config_default();
            
            % 시스템 파라미터
            cfg.num_stas = sc.num_sta;
            cfg.num_ru_ra = sc.num_ra_ru;
            cfg.num_ru_total = sc.num_ra_ru + sc.num_sa_ru;
            cfg.num_ru_sa = sc.num_sa_ru;
            
            % 트래픽 파라미터
            cfg.traffic_model = 'pareto_onoff';
            cfg.lambda = traffic.lambda;
            cfg.rho = traffic.rho;
            cfg.mu_on = traffic.mu_on;
            cfg.mu_off = traffic.mu_off;
            cfg.pareto_alpha = 1.5;
            
            % 시뮬레이션 설정
            cfg.simulation_time = sim_time;
            cfg.seed = seed;
            cfg.verbose = 0;
            
            % T_hold 설정
            if strcmp(method, 'Baseline')
                cfg.thold_enabled = false;
            else
                cfg.thold_enabled = true;
                cfg.thold_value = thold_ms / 1000;
                cfg.thold_method = 'M2';
            end
            
            % 시뮬레이션 실행
            tic;
            r = run_simulation(cfg);
            elapsed = toc;
            
            % 메타데이터 추가
            r.scenario = sc.name;
            r.scenario_key = sc_key;
            r.method = method;
            r.seed = seed;
            r.seed_idx = seed_idx;
            r.label = run_label;
            r.cfg = cfg;
            r.system_params = struct('num_stas', sc.num_sta, ...
                'num_ru_ra', sc.num_ra_ru, 'num_ru_sa', sc.num_sa_ru);
            
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
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                   추가 실험 1 결과 요약 (3회 반복 평균 ± std)                              ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌────────┬──────────┬─────────────────┬─────────────────┬─────────────────┬─────────────────┐\n');
fprintf('│ 시나리오 │  Method  │ Mean Delay      │ P90 Delay       │ Hit Rate        │ Phantoms        │\n');
fprintf('├────────┼──────────┼─────────────────┼─────────────────┼─────────────────┼─────────────────┤\n');

for sc_idx = 1:length(scenario_names)
    sc_key = scenario_names{sc_idx};
    sc = scenarios.(sc_key);
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        
        delays = [];
        p90s = [];
        hit_rates = [];
        phantoms_arr = [];
        
        for seed_idx = 1:num_seeds
            field_name = sprintf('%s_%s_s%d', sc.name, method, seed_idx);
            field_name = strrep(field_name, '-', '_');
            
            if isfield(results.runs, field_name)
                r = results.runs.(field_name);
                delays(end+1) = r.delay.mean_ms;
                p90s(end+1) = r.delay.p90_ms;
                
                if isfield(r, 'thold') && isfield(r.thold, 'hit_rate')
                    hit_rates(end+1) = r.thold.hit_rate * 100;
                    phantoms_arr(end+1) = r.thold.phantoms;
                end
            end
        end
        
        if ~isempty(delays)
            if strcmp(method, 'Baseline')
                fprintf('│  %s   │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │      N/A        │      N/A        │\n', ...
                    sc.name, method, mean(delays), std(delays), mean(p90s), std(p90s));
            else
                fprintf('│  %s   │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %5.1f%% ± %4.1f%% │ %6.0f ± %5.0f  │\n', ...
                    sc.name, method, mean(delays), std(delays), mean(p90s), std(p90s), ...
                    mean(hit_rates), std(hit_rates), mean(phantoms_arr), std(phantoms_arr));
            end
        end
    end
end
fprintf('└────────┴──────────┴─────────────────┴─────────────────┴─────────────────┴─────────────────┘\n');

% Baseline 대비 개선율
fprintf('\n[Baseline 대비 M2 지연 개선율]\n');
fprintf('┌────────┬───────────────────────────────┐\n');
fprintf('│ 시나리오 │ M2 개선율                      │\n');
fprintf('├────────┼───────────────────────────────┤\n');

for sc_idx = 1:length(scenario_names)
    sc_key = scenario_names{sc_idx};
    sc = scenarios.(sc_key);
    
    % Baseline 평균
    base_delays = [];
    for seed_idx = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc.name, seed_idx);
        field_name = strrep(field_name, '-', '_');
        if isfield(results.runs, field_name)
            base_delays(end+1) = results.runs.(field_name).delay.mean_ms;
        end
    end
    
    % M2 평균
    m2_delays = [];
    for seed_idx = 1:num_seeds
        field_name = sprintf('%s_M2_s%d', sc.name, seed_idx);
        field_name = strrep(field_name, '-', '_');
        if isfield(results.runs, field_name)
            m2_delays(end+1) = results.runs.(field_name).delay.mean_ms;
        end
    end
    
    if ~isempty(base_delays) && ~isempty(m2_delays)
        improvement = (mean(base_delays) - mean(m2_delays)) / mean(base_delays) * 100;
        fprintf('│  %s   │ %+6.1f%% (%5.1f → %5.1f ms)   │\n', ...
            sc.name, improvement, mean(base_delays), mean(m2_delays));
    end
end
fprintf('└────────┴───────────────────────────────┘\n');

fprintf('\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  추가 실험 1 완료!\n');
fprintf('  결과 파일: %s\n', output_file);
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');