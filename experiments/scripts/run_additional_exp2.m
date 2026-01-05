%% run_additional_exp2.m
% 추가 실험 2: 제안 기법의 한계 확인
%
% 목적: 다양한 극단적 상황에서 M2 기법의 한계 분석
%
% 실험 설계:
%   - 시나리오: E (긴 On), F (고부하+burst), G (Poisson)
%   - 방법: Baseline, M2
%   - T_hold: 50ms (M2만)
%   - 반복: 3회
%   - 총 runs: 3 시나리오 × 2 방법 × 3 반복 = 18

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║           추가 실험 2: 제안 기법의 한계 확인                       ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════════════

seeds = [1234, 5678, 9012];
sim_time = 20;

% T_hold 설정
thold_ms = 50;

% 시나리오 정의
scenarios = struct();

% Scenario E: 긴 On 구간 → T_hold 발동 빈도 감소
scenarios.E.name = 'E';
scenarios.E.description = '긴 On 구간';
scenarios.E.traffic_model = 'pareto_onoff';
scenarios.E.lambda = 100;
scenarios.E.rho = 0.70;
scenarios.E.mu_off = 0.050;  % 50ms
scenarios.E.mu_on = scenarios.E.rho * scenarios.E.mu_off / (1 - scenarios.E.rho);  % 117ms
scenarios.E.load_pps = 1400;
scenarios.E.capacity_ratio = 49;
scenarios.E.expected_behavior = 'T_hold 발동 빈도 감소';

% Scenario F: 고부하 + burst → 고부하에서 T_hold 한계
scenarios.F.name = 'F';
scenarios.F.description = '고부하 + burst';
scenarios.F.traffic_model = 'pareto_onoff';
scenarios.F.lambda = 400;
scenarios.F.rho = 0.30;
scenarios.F.mu_off = 0.050;  % 50ms
scenarios.F.mu_on = scenarios.F.rho * scenarios.F.mu_off / (1 - scenarios.F.rho);  % 21ms
scenarios.F.load_pps = 2400;
scenarios.F.capacity_ratio = 83;
scenarios.F.expected_behavior = '고부하에서 T_hold 한계';

% Scenario G: Poisson 트래픽 → On/Off 패턴 없을 때 효과
scenarios.G.name = 'G';
scenarios.G.description = 'Poisson 트래픽';
scenarios.G.traffic_model = 'poisson';
scenarios.G.lambda = 100;  % STA당 100 pkt/s
scenarios.G.rho = NaN;  % Poisson은 rho 없음
scenarios.G.mu_off = NaN;
scenarios.G.mu_on = NaN;
scenarios.G.load_pps = 2000;  % 20 STA × 100 pkt/s
scenarios.G.capacity_ratio = 69;
scenarios.G.expected_behavior = 'On/Off 패턴 없을 때 효과';

scenario_names = {'E', 'F', 'G'};

% 방법
methods = {'Baseline', 'M2'};

% 결과 저장 경로
output_dir = 'results/additional_exp2';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 총 실험 수
num_seeds = length(seeds);
total_runs = length(scenario_names) * length(methods) * num_seeds;

fprintf('[실험 설정]\n');
fprintf('  시나리오: E (긴 On), F (고부하+burst), G (Poisson)\n');
fprintf('  방법: Baseline, M2\n');
fprintf('  T_hold: %dms (M2)\n', thold_ms);
fprintf('  반복: %d회 (seeds: %s)\n', num_seeds, mat2str(seeds));
fprintf('  총 runs: %d\n', total_runs);
fprintf('  Sim time: %d초\n', sim_time);
fprintf('  Output: %s/\n\n', output_dir);

% 시나리오 파라미터 출력
fprintf('[시나리오 파라미터]\n');
fprintf('┌────────┬─────────────────┬───────┬─────────┬────────┬────────────┬──────────┐\n');
fprintf('│ 시나리오 │ 특성             │  ρ    │ μ_on    │   λ    │ 전체 부하   │ 용량 대비 │\n');
fprintf('├────────┼─────────────────┼───────┼─────────┼────────┼────────────┼──────────┤\n');
for i = 1:length(scenario_names)
    sc = scenarios.(scenario_names{i});
    if strcmp(sc.traffic_model, 'poisson')
        fprintf('│   %s    │ %-15s │   -   │    -    │  %3d   │ %4d pkt/s │   %2d%%    │\n', ...
            sc.name, sc.description, sc.lambda, sc.load_pps, sc.capacity_ratio);
    else
        fprintf('│   %s    │ %-15s │ %.2f  │ %5.0fms │  %3d   │ %4d pkt/s │   %2d%%    │\n', ...
            sc.name, sc.description, sc.rho, sc.mu_on*1000, sc.lambda, sc.load_pps, sc.capacity_ratio);
    end
end
fprintf('└────────┴─────────────────┴───────┴─────────┴────────┴────────────┴──────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 실행
%  ═══════════════════════════════════════════════════════════════════════════

results = struct();
results.scenarios = scenarios;
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
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    fprintf('\n[시나리오 %s: %s]\n', sc.name, sc.description);
    fprintf('  예상 동작: %s\n', sc.expected_behavior);
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        
        for seed_idx = 1:num_seeds
            seed = seeds(seed_idx);
            run_count = run_count + 1;
            
            run_label = sprintf('%s_%s_s%d', sc.name, method, seed_idx);
            fprintf('[%3d/%d] %s ... ', run_count, total_runs, run_label);
            
            % Config 설정
            cfg = config_default();
            
            % 트래픽 파라미터
            cfg.traffic_model = sc.traffic_model;
            cfg.lambda = sc.lambda;
            
            if strcmp(sc.traffic_model, 'pareto_onoff')
                cfg.rho = sc.rho;
                cfg.mu_on = sc.mu_on;
                cfg.mu_off = sc.mu_off;
                cfg.pareto_alpha = 1.5;
            end
            % Poisson인 경우 lambda만 설정하면 됨
            
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
            r.method = method;
            r.seed = seed;
            r.seed_idx = seed_idx;
            r.label = run_label;
            r.cfg = cfg;
            r.traffic_model = sc.traffic_model;
            r.expected_behavior = sc.expected_behavior;
            
            results.runs.(run_label) = r;
            fprintf('완료 (%.1fs)\n', elapsed);
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

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 요약 출력
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                   추가 실험 2 결과 요약 (3회 반복 평균 ± std)                              ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌────────┬──────────┬─────────────────┬─────────────────┬─────────────────┬─────────────────┐\n');
fprintf('│ 시나리오 │  Method  │ Mean Delay      │ P90 Delay       │ Hit Rate        │ Phantoms        │\n');
fprintf('├────────┼──────────┼─────────────────┼─────────────────┼─────────────────┼─────────────────┤\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        
        delays = [];
        p90s = [];
        hit_rates = [];
        phantoms_arr = [];
        activations_arr = [];
        
        for seed_idx = 1:num_seeds
            field_name = sprintf('%s_%s_s%d', sc.name, method, seed_idx);
            
            if isfield(results.runs, field_name)
                r = results.runs.(field_name);
                delays(end+1) = r.delay.mean_ms;
                p90s(end+1) = r.delay.p90_ms;
                
                if isfield(r, 'thold') && isfield(r.thold, 'hit_rate')
                    hit_rates(end+1) = r.thold.hit_rate * 100;
                    phantoms_arr(end+1) = r.thold.phantoms;
                    activations_arr(end+1) = r.thold.activations;
                end
            end
        end
        
        if ~isempty(delays)
            if strcmp(method, 'Baseline')
                fprintf('│   %s    │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │      N/A        │      N/A        │\n', ...
                    sc.name, method, mean(delays), std(delays), mean(p90s), std(p90s));
            else
                fprintf('│   %s    │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %5.1f%% ± %4.1f%% │ %6.0f ± %5.0f  │\n', ...
                    sc.name, method, mean(delays), std(delays), mean(p90s), std(p90s), ...
                    mean(hit_rates), std(hit_rates), mean(phantoms_arr), std(phantoms_arr));
            end
        end
    end
end
fprintf('└────────┴──────────┴─────────────────┴─────────────────┴─────────────────┴─────────────────┘\n');

% Baseline 대비 개선율 및 특성 분석
fprintf('\n[Baseline 대비 M2 분석]\n');
fprintf('┌────────┬───────────────────────────────┬─────────────────────────────────────┐\n');
fprintf('│ 시나리오 │ M2 지연 개선율                 │ T_hold Activations (M2)             │\n');
fprintf('├────────┼───────────────────────────────┼─────────────────────────────────────┤\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    
    % Baseline 평균
    base_delays = [];
    for seed_idx = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc.name, seed_idx);
        if isfield(results.runs, field_name)
            base_delays(end+1) = results.runs.(field_name).delay.mean_ms;
        end
    end
    
    % M2 평균
    m2_delays = [];
    m2_activations = [];
    for seed_idx = 1:num_seeds
        field_name = sprintf('%s_M2_s%d', sc.name, seed_idx);
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            m2_delays(end+1) = r.delay.mean_ms;
            if isfield(r, 'thold')
                m2_activations(end+1) = r.thold.activations;
            end
        end
    end
    
    if ~isempty(base_delays) && ~isempty(m2_delays)
        improvement = (mean(base_delays) - mean(m2_delays)) / mean(base_delays) * 100;
        fprintf('│   %s    │ %+6.1f%% (%5.1f → %5.1f ms)   │ %6.0f ± %5.0f                       │\n', ...
            sc.name, improvement, mean(base_delays), mean(m2_delays), ...
            mean(m2_activations), std(m2_activations));
    end
end
fprintf('└────────┴───────────────────────────────┴─────────────────────────────────────┘\n');

% 시나리오별 해석
fprintf('\n[시나리오별 해석]\n');
for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = scenarios.(sc_name);
    fprintf('  %s (%s): %s\n', sc.name, sc.description, sc.expected_behavior);
end

fprintf('\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  추가 실험 2 완료!\n');
fprintf('  결과 파일: %s\n', output_file);
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');