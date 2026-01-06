%% run_m1_quick.m
% M0 vs M1 max_phantom 탐색 실험
%
% 목적: M0과 M1(다양한 max_phantom)의 Trade-off 파악
%       → 본 실험에서 사용할 M1 설정 결정
%
% 테스트: Baseline, M0, M1(1,3,5,10)
% 시각화 없음 (analyze_m1_quick.m에서 수행)

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║           M1 max_phantom 탐색 실험 (Quick Test)                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════════════

seed = 1234;
thold_ms = 50;
sim_time = 10;  % 초

% 테스트 케이스: M0, M1(1,3,5,10)
test_cases = {
    'M0', Inf,  'M0';
    'M1', 1,    'M1(1)';
    'M1', 3,    'M1(3)';
    'M1', 5,    'M1(5)';
    'M1', 10,   'M1(10)';
};

% Scenario A
mu_off = 0.050;
scenario.name = 'A';
scenario.lambda = 100;
scenario.rho = 0.30;
scenario.mu_off = mu_off;
scenario.mu_on = scenario.rho * mu_off / (1 - scenario.rho);

% 결과 저장 경로
output_dir = 'results/m1_quick';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('[설정]\n');
fprintf('  목적: M0 vs M1(다양한 max_phantom) Trade-off 파악\n');
fprintf('  Scenario %s: λ=%d, ρ=%.2f, mu_on=%.1fms, mu_off=%.0fms\n', ...
    scenario.name, scenario.lambda, scenario.rho, scenario.mu_on*1000, scenario.mu_off*1000);
fprintf('  T_hold: %dms\n', thold_ms);
fprintf('  Seed: %d\n', seed);
fprintf('  Simulation: %d초\n', sim_time);
fprintf('  Output: %s/\n\n', output_dir);

%% ═══════════════════════════════════════════════════════════════════════════
%  실험 실행
%  ═══════════════════════════════════════════════════════════════════════════

% Baseline
fprintf('[1/%d] Baseline 실행 중... ', size(test_cases, 1) + 1);
cfg = config_default();
cfg.traffic_model = 'pareto_onoff';
cfg.lambda = scenario.lambda;
cfg.rho = scenario.rho;
cfg.mu_on = scenario.mu_on;
cfg.mu_off = scenario.mu_off;
cfg.pareto_alpha = 1.5;
cfg.simulation_time = sim_time;
cfg.seed = seed;
cfg.verbose = 0;
cfg.thold_enabled = false;

tic;
r_base = run_simulation(cfg);
elapsed = toc;
r_base.label = 'Baseline';
r_base.cfg = cfg;
fprintf('완료 (%.1fs)\n', elapsed);

% 결과 저장
results = struct();
results.baseline = r_base;
results.labels = {'Baseline'};

% 테스트 케이스들
for i = 1:size(test_cases, 1)
    method = test_cases{i, 1};
    max_phantom = test_cases{i, 2};
    label = test_cases{i, 3};
    
    fprintf('[%d/%d] %s 실행 중... ', i+1, size(test_cases, 1)+1, label);
    
    cfg = config_default();
    cfg.traffic_model = 'pareto_onoff';
    cfg.lambda = scenario.lambda;
    cfg.rho = scenario.rho;
    cfg.mu_on = scenario.mu_on;
    cfg.mu_off = scenario.mu_off;
    cfg.pareto_alpha = 1.5;
    cfg.simulation_time = sim_time;
    cfg.seed = seed;
    cfg.verbose = 0;
    cfg.thold_enabled = true;
    cfg.thold_value = thold_ms / 1000;
    cfg.thold_method = method;
    cfg.thold_max_phantom = max_phantom;
    
    tic;
    r = run_simulation(cfg);
    elapsed = toc;
    
    r.label = label;
    r.max_phantom = max_phantom;
    r.cfg = cfg;
    
    % 필드명으로 저장 (M0, M1_1, M1_3 등)
    field_name = strrep(label, '(', '_');
    field_name = strrep(field_name, ')', '');
    results.(field_name) = r;
    results.labels{end+1} = label;
    
    fprintf('완료 (%.1fs)\n', elapsed);
end

% 메타데이터 저장
results.meta.scenario = scenario;
results.meta.thold_ms = thold_ms;
results.meta.seed = seed;
results.meta.sim_time = sim_time;
results.meta.timestamp = datetime('now');

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 저장
%  ═══════════════════════════════════════════════════════════════════════════

output_file = fullfile(output_dir, 'results.mat');
save(output_file, 'results');
fprintf('\n결과 저장: %s\n', output_file);

%% ═══════════════════════════════════════════════════════════════════════════
%  텍스트 요약 출력
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                                        결과 요약                                                                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

% 지연 통계 테이블
fprintf('[지연 통계]\n');
fprintf('┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐\n');
fprintf('│ Case     │ Mean     │ Std      │ Min      │ P10      │ P50      │ P90      │ P99      │ Max      │ Pkts     │\n');
fprintf('├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤\n');

all_results = {results.baseline};
fields = fieldnames(results);
for i = 1:length(fields)
    if ~ismember(fields{i}, {'baseline', 'labels', 'meta'}) && isstruct(results.(fields{i}))
        all_results{end+1} = results.(fields{i});
    end
end

for i = 1:length(all_results)
    r = all_results{i};
    fprintf('│ %-8s │ %8.2f │ %8.2f │ %8.2f │ %8.2f │ %8.2f │ %8.2f │ %8.2f │ %8.2f │ %8d │\n', ...
        r.label, r.delay.mean_ms, r.delay.std_ms, r.delay.min_ms, ...
        r.delay.p10_ms, r.delay.p50_ms, r.delay.p90_ms, r.delay.p99_ms, r.delay.max_ms, ...
        r.packets.completed);
end
fprintf('└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘\n\n');

% T_hold 통계 테이블
fprintf('[T_hold 통계]\n');
fprintf('┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐\n');
fprintf('│ Case     │ Activate │ Hits     │ HitRate  │ Expire   │ CleanExp │ ExpData  │ Phantoms │ Phan/Act │\n');
fprintf('├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤\n');

for i = 1:length(all_results)
    r = all_results{i};
    if isfield(r, 'thold') && isfield(r.thold, 'activations') && r.thold.activations > 0
        fprintf('│ %-8s │ %8d │ %8d │ %7.1f%% │ %8d │ %8d │ %8d │ %8d │ %8.2f │\n', ...
            r.label, r.thold.activations, r.thold.hits, r.thold.hit_rate*100, ...
            r.thold.expirations, r.thold.clean_exp, r.thold.exp_with_data, ...
            r.thold.phantoms, r.thold.phantom_per_activation);
    else
        fprintf('│ %-8s │ %8s │ %8s │ %8s │ %8s │ %8s │ %8s │ %8s │ %8s │\n', ...
            r.label, 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A', 'N/A');
    end
end
fprintf('└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘\n\n');

% 패킷 분류 테이블
fprintf('[패킷 분류 - UORA 스킵 여부]\n');
fprintf('┌──────────┬─────────────────────────────────────┬─────────────────────────────────────┐\n');
fprintf('│ Case     │ UORA Skipped (cnt / %% / mean)      │ UORA Used (cnt / %% / mean)         │\n');
fprintf('├──────────┼─────────────────────────────────────┼─────────────────────────────────────┤\n');

for i = 1:length(all_results)
    r = all_results{i};
    fprintf('│ %-8s │ %5d / %5.1f%% / %7.2fms         │ %5d / %5.1f%% / %7.2fms         │\n', ...
        r.label, ...
        r.pkt_class.uora_skipped.count, r.pkt_class.uora_skipped.ratio*100, r.pkt_class.uora_skipped.mean_ms, ...
        r.pkt_class.uora_used.count, r.pkt_class.uora_used.ratio*100, r.pkt_class.uora_used.mean_ms);
end
fprintf('└──────────┴─────────────────────────────────────┴─────────────────────────────────────┘\n\n');

% 스킵 이유별
fprintf('[패킷 분류 - 스킵 이유별]\n');
fprintf('┌──────────┬─────────────────────────────────────┬─────────────────────────────────────┐\n');
fprintf('│ Case     │ T_hold Hit (cnt / %% / mean)        │ SA Queue (cnt / %% / mean)          │\n');
fprintf('├──────────┼─────────────────────────────────────┼─────────────────────────────────────┤\n');

for i = 1:length(all_results)
    r = all_results{i};
    fprintf('│ %-8s │ %5d / %5.1f%% / %7.2fms         │ %5d / %5.1f%% / %7.2fms         │\n', ...
        r.label, ...
        r.pkt_class.thold_hit.count, r.pkt_class.thold_hit.ratio*100, r.pkt_class.thold_hit.mean_ms, ...
        r.pkt_class.sa_queue.count, r.pkt_class.sa_queue.ratio*100, r.pkt_class.sa_queue.mean_ms);
end
fprintf('└──────────┴─────────────────────────────────────┴─────────────────────────────────────┘\n\n');

% UORA 통계
fprintf('[UORA 통계]\n');
fprintf('┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐\n');
fprintf('│ Case     │ Success  │ Collision│ Idle     │ SuccRate │ CollRate │ IdleRate │\n');
fprintf('├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤\n');

for i = 1:length(all_results)
    r = all_results{i};
    fprintf('│ %-8s │ %8d │ %8d │ %8d │ %7.1f%% │ %7.1f%% │ %7.1f%% │\n', ...
        r.label, r.uora.total_success, r.uora.total_collision_slots, r.uora.total_idle, ...
        r.uora.success_rate*100, r.uora.collision_slot_rate*100, r.uora.idle_rate*100);
end
fprintf('└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘\n\n');

% 처리율 & 공정성
fprintf('[처리율 & 공정성]\n');
fprintf('┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐\n');
fprintf('│ Case     │ Thruput  │ ChanUtil │ SA_Phan  │ Jain     │ CoV      │\n');
fprintf('│          │ (Mbps)   │ (%%)      │ (%%)      │          │          │\n');
fprintf('├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤\n');

for i = 1:length(all_results)
    r = all_results{i};
    fprintf('│ %-8s │ %8.2f │ %7.1f%% │ %7.1f%% │ %8.4f │ %8.4f │\n', ...
        r.label, r.throughput.total_mbps, r.throughput.channel_utilization*100, ...
        r.throughput.sa_phantom_rate*100, r.fairness.jain_index, r.fairness.cov);
end
fprintf('└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘\n\n');

% BSR 통계
fprintf('[BSR 통계]\n');
fprintf('┌──────────┬──────────┬──────────┬──────────┐\n');
fprintf('│ Case     │ Explicit │ Implicit │ Exp%%     │\n');
fprintf('├──────────┼──────────┼──────────┼──────────┤\n');

for i = 1:length(all_results)
    r = all_results{i};
    fprintf('│ %-8s │ %8d │ %8d │ %7.1f%% │\n', ...
        r.label, r.bsr.explicit_count, r.bsr.implicit_count, r.bsr.explicit_ratio*100);
end
fprintf('└──────────┴──────────┴──────────┴──────────┘\n\n');

% Baseline 대비 변화율
fprintf('[Baseline 대비 변화율]\n');
r_b = results.baseline;
for i = 2:length(all_results)
    r = all_results{i};
    delay_change = (r.delay.mean_ms - r_b.delay.mean_ms) / r_b.delay.mean_ms * 100;
    p90_change = (r.delay.p90_ms - r_b.delay.p90_ms) / r_b.delay.p90_ms * 100;
    
    fprintf('  %s: 평균지연 %+.1f%% (%.2f→%.2fms), P90 %+.1f%% (%.2f→%.2fms)\n', ...
        r.label, delay_change, r_b.delay.mean_ms, r.delay.mean_ms, ...
        p90_change, r_b.delay.p90_ms, r.delay.p90_ms);
end

fprintf('\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  시뮬레이션 완료!\n');
fprintf('  결과 파일: %s\n', output_file);
fprintf('  시각화: analyze_m1_quick 실행\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');