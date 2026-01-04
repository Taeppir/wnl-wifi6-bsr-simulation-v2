%% run_p1_m0.m
% ═══════════════════════════════════════════════════════════════════════════
% Priority 1 - M0 (Original) 실험
% ═══════════════════════════════════════════════════════════════════════════
%
% 시나리오: A (VoIP), B (Video), S (Stress)
% Method: M0 (Original - Phantom 허용)
% T_hold: [0, 10, 30, 50] ms  (T_hold=0은 Baseline과 동일)
% 총 runs: 3 × 4 = 12
%
% 사용법:
%   cd('wnl-wifi6-bsr-simulation-v2-main')
%   setup_paths
%   run_p1_m0
%
% ═══════════════════════════════════════════════════════════════════════════

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║         Priority 1 - M0 실험 (12 runs)                           ║\n');
fprintf('║         시나리오: A/B/S × T_hold: 0/10/30/50ms                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════════════

% T_hold 값 (ms → 초)
thold_values_ms = [0, 10, 30, 50];
thold_values = thold_values_ms / 1000;

% 공통 고정값
mu_off = 0.050;  % 50ms 고정 (모든 시나리오 동일)

% 시나리오 정의 (mu_on은 rho로부터 자동 계산)
% 공식: mu_on = rho * mu_off / (1 - rho)
scenarios = struct();

% Scenario A: VoIP-like
scenarios.A.name = 'VoIP-like';
scenarios.A.lambda = 100;       % λ_on (pkt/s)
scenarios.A.rho = 0.30;
scenarios.A.mu_off = mu_off;
scenarios.A.mu_on = scenarios.A.rho * mu_off / (1 - scenarios.A.rho);

% Scenario B: Video-like
scenarios.B.name = 'Video-like';
scenarios.B.lambda = 200;
scenarios.B.rho = 0.40;
scenarios.B.mu_off = mu_off;
scenarios.B.mu_on = scenarios.B.rho * mu_off / (1 - scenarios.B.rho);

% Scenario S: Stress
scenarios.S.name = 'Stress';
scenarios.S.lambda = 400;
scenarios.S.rho = 0.30;
scenarios.S.mu_off = mu_off;
scenarios.S.mu_on = scenarios.S.rho * mu_off / (1 - scenarios.S.rho);

scenario_keys = {'A', 'B', 'S'};

% 공통 설정
common_cfg.simulation_time = 30;    % 30초
common_cfg.seed_base = 1000;        % 시드 기본값
common_cfg.verbose = 0;
common_cfg.method = 'M0';           % Method 식별자

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 저장 구조체
%  ═══════════════════════════════════════════════════════════════════════════

results_all = struct();
run_count = 0;
total_runs = length(scenario_keys) * length(thold_values);

% 결과 저장 디렉토리 (날짜별)
date_str = datestr(now, 'yyyymmdd');
output_base = fullfile('results', date_str);
output_dir = fullfile(output_base, 'p1_m0');

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 시나리오 파라미터 출력
fprintf('[시나리오 파라미터]\n');
fprintf('  mu_off = %.0f ms (고정)\n\n', mu_off * 1000);
for s = 1:length(scenario_keys)
    sc = scenarios.(scenario_keys{s});
    lambda_avg = sc.rho * sc.lambda;
    utilization = (lambda_avg * 20) / 2886 * 100;
    fprintf('  %s (%s):\n', scenario_keys{s}, sc.name);
    fprintf('    λ_on=%d, ρ=%.2f, mu_on=%.1fms\n', sc.lambda, sc.rho, sc.mu_on*1000);
    fprintf('    λ_avg=%.0f pkt/s, 이용률=%.1f%%\n\n', lambda_avg, utilization);
end

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 실행
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('[실험 시작] %s\n\n', datestr(now));
total_start = tic;

for s = 1:length(scenario_keys)
    scenario_key = scenario_keys{s};
    scenario = scenarios.(scenario_key);
    
    fprintf('═══════════════════════════════════════════════════════════════════\n');
    fprintf('시나리오 %s: %s\n', scenario_key, scenario.name);
    fprintf('  λ_on=%d, ρ=%.2f, mu_on=%.0fms, mu_off=%.0fms\n', ...
        scenario.lambda, scenario.rho, scenario.mu_on*1000, scenario.mu_off*1000);
    fprintf('═══════════════════════════════════════════════════════════════════\n\n');
    
    for t = 1:length(thold_values)
        thold = thold_values(t);
        thold_ms = thold_values_ms(t);
        run_count = run_count + 1;
        
        fprintf('[Run %d/%d] T_hold = %d ms\n', run_count, total_runs, thold_ms);
        
        % Config 생성
        cfg = config_default();
        
        % 트래픽 설정
        cfg.traffic_model = 'pareto_onoff';
        cfg.lambda = scenario.lambda;
        cfg.rho = scenario.rho;
        cfg.mu_on = scenario.mu_on;
        cfg.mu_off = scenario.mu_off;
        cfg.pareto_alpha = 1.5;
        
        % T_hold 설정
        if thold == 0
            cfg.thold_enabled = false;
        else
            cfg.thold_enabled = true;
            cfg.thold_value = thold;
        end
        
        % 공통 설정
        cfg.simulation_time = common_cfg.simulation_time;
        cfg.seed = common_cfg.seed_base + run_count;
        cfg.verbose = common_cfg.verbose;
        
        % 실행
        run_start = tic;
        result = run_simulation(cfg);
        run_elapsed = toc(run_start);
        
        % 결과 저장
        result.scenario = scenario_key;
        result.scenario_name = scenario.name;
        result.method = common_cfg.method;
        result.thold_ms = thold_ms;
        result.elapsed_time = run_elapsed;
        result.cfg = cfg;
        
        % 구조체에 저장
        field_name = sprintf('%s_%s_T%d', scenario_key, common_cfg.method, thold_ms);
        results_all.(field_name) = result;
        
        % 개별 파일 저장 (새 네이밍: A_M0_T0.mat)
        result_filename = sprintf('%s_%s_T%d.mat', scenario_key, common_cfg.method, thold_ms);
        save(fullfile(output_dir, result_filename), 'result');
        
        % 결과 출력
        fprintf('  완료: %.1f초 소요\n', run_elapsed);
        fprintf('  패킷: %d 생성, %d 완료 (%.1f%%)\n', ...
            result.packets.generated, result.packets.completed, ...
            result.packets.completion_rate * 100);
        fprintf('  지연: 평균 %.2f ms, P90 %.2f ms\n', ...
            result.delay.mean_ms, result.delay.p90_ms);
        fprintf('  Throughput: %.2f Mbps\n', result.throughput.total_mbps);
        
        if cfg.thold_enabled
            fprintf('  T_hold: Hit Rate %.1f%% (%d/%d)\n', ...
                result.thold.hit_rate * 100, result.thold.hits, result.thold.activations);
        end
        fprintf('\n');
    end
end

total_elapsed = toc(total_start);

%% ═══════════════════════════════════════════════════════════════════════════
%  전체 결과 저장
%  ═══════════════════════════════════════════════════════════════════════════

% 전체 MAT 파일 저장
save(fullfile(output_dir, 'p1_m0_all.mat'), 'results_all');

% CSV 요약 저장
summary_file = fullfile(output_dir, 'p1_m0_summary.csv');
fid = fopen(summary_file, 'w');
fprintf(fid, 'Scenario,Method,T_hold_ms,Pkts_Gen,Pkts_Done,Completion_Rate,');
fprintf(fid, 'Delay_Mean_ms,Delay_P90_ms,Delay_P99_ms,');
fprintf(fid, 'Throughput_Mbps,');
fprintf(fid, 'UORA_Success_Rate,UORA_Collision_Rate,');
fprintf(fid, 'THold_Activations,THold_Hits,THold_HitRate,');
fprintf(fid, 'Elapsed_sec\n');

for s = 1:length(scenario_keys)
    for t = 1:length(thold_values_ms)
        field_name = sprintf('%s_%s_T%d', scenario_keys{s}, common_cfg.method, thold_values_ms(t));
        r = results_all.(field_name);
        
        fprintf(fid, '%s,%s,%d,%d,%d,%.4f,', ...
            r.scenario, r.method, r.thold_ms, r.packets.generated, r.packets.completed, ...
            r.packets.completion_rate);
        fprintf(fid, '%.4f,%.4f,%.4f,', ...
            r.delay.mean_ms, r.delay.p90_ms, r.delay.p99_ms);
        fprintf(fid, '%.4f,', r.throughput.total_mbps);
        fprintf(fid, '%.4f,%.4f,', ...
            r.uora.success_rate, r.uora.collision_rate);
        
        if isfield(r, 'thold') && r.thold_ms > 0
            fprintf(fid, '%d,%d,%.4f,', ...
                r.thold.activations, r.thold.hits, r.thold.hit_rate);
        else
            fprintf(fid, '0,0,0,');
        end
        
        fprintf(fid, '%.1f\n', r.elapsed_time);
    end
end
fclose(fid);

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 요약 출력
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                   Priority 1 - M0 실험 완료                       ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

fprintf('[실행 정보]\n');
fprintf('  Method: %s (Original)\n', common_cfg.method);
fprintf('  총 runs: %d\n', total_runs);
fprintf('  총 소요 시간: %.1f분 (%.1f초)\n', total_elapsed/60, total_elapsed);
fprintf('  평균 run 시간: %.1f초\n', total_elapsed/total_runs);
fprintf('  결과 저장: %s/\n\n', output_dir);

fprintf('[결과 요약]\n');
fprintf('┌──────────┬────────┬──────────┬──────────┬──────────┬──────────┬──────────┐\n');
fprintf('│ Scenario │ Method │ T_hold   │ Delay    │ P90      │ Hit Rate │ Thruput  │\n');
fprintf('│          │        │ (ms)     │ (ms)     │ (ms)     │ (%%)      │ (Mbps)   │\n');
fprintf('├──────────┼────────┼──────────┼──────────┼──────────┼──────────┼──────────┤\n');

for s = 1:length(scenario_keys)
    for t = 1:length(thold_values_ms)
        field_name = sprintf('%s_%s_T%d', scenario_keys{s}, common_cfg.method, thold_values_ms(t));
        r = results_all.(field_name);
        
        if r.thold_ms > 0 && isfield(r, 'thold')
            hit_rate = r.thold.hit_rate * 100;
        else
            hit_rate = 0;
        end
        
        fprintf('│ %-8s │ %-6s │ %8d │ %8.2f │ %8.2f │ %8.1f │ %8.2f │\n', ...
            r.scenario_name, r.method, r.thold_ms, r.delay.mean_ms, r.delay.p90_ms, ...
            hit_rate, r.throughput.total_mbps);
    end
    if s < length(scenario_keys)
        fprintf('├──────────┼────────┼──────────┼──────────┼──────────┼──────────┼──────────┤\n');
    end
end

fprintf('└──────────┴────────┴──────────┴──────────┴──────────┴──────────┴──────────┘\n\n');

fprintf('[저장된 파일]\n');
fprintf('  MAT: %s/p1_m0_all.mat\n', output_dir);
fprintf('  CSV: %s\n', summary_file);
fprintf('\n완료 시각: %s\n\n', datestr(now));