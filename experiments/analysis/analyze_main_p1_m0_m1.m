%% analyze_main_m0_m1.m
% 본 실험: M0 vs M1(5) 결과 분석 및 시각화
%
% - 저장된 결과 (.mat) 로드
% - 시나리오별/T_hold별 비교 분석
% - 시각화 (Figure 생성)
% - 시뮬레이션 실행 없음

clear; clc; close all;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║          본 실험: M0 vs M1(5) 결과 분석 및 시각화                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 로드
%  ═══════════════════════════════════════════════════════════════════════════

input_file = 'results/main_m0_m1/results.mat';

if ~exist(input_file, 'file')
    error('결과 파일이 없습니다: %s\n먼저 run_main_m0_m1 실행하세요.', input_file);
end

fprintf('[결과 로드] %s\n', input_file);
load(input_file, 'results');

% 메타데이터 출력
fprintf('\n[메타데이터]\n');
fprintf('  반복: %d회\n', results.meta.num_repeats);
fprintf('  Seeds: %s\n', mat2str(results.seeds));
fprintf('  Sim time: %d초\n', results.meta.sim_time);
fprintf('  Timestamp: %s\n', string(results.meta.timestamp));

scenario_names = {'A', 'B', 'C'};
thold_values = results.thold_values_ms;
method_labels = {'Baseline', 'M0', 'M1(5)'};
num_seeds = results.meta.num_repeats;

fprintf('  Scenarios: %s\n', strjoin(scenario_names, ', '));
fprintf('  T_hold: %s ms\n', mat2str(thold_values));
fprintf('  Methods: %s\n\n', strjoin(method_labels, ', '));

% 결과 디렉토리
output_dir = 'results/main_m0_m1';

%% ═══════════════════════════════════════════════════════════════════════════
%  헬퍼 함수: 결과 가져오기
%  ═══════════════════════════════════════════════════════════════════════════

get_result = @(sc, th, method) get_run_result(results, sc, th, method);

%% ═══════════════════════════════════════════════════════════════════════════
%  전체 지표 텍스트 출력 (반복 평균)
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                 전체 결과 요약 테이블 (3회 평균)                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    sc = results.scenarios.(sc_name);
    
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('  시나리오 %s: %s (λ=%d, ρ=%.2f, mu_on=%.1fms, mu_off=%.0fms)\n', ...
        sc_name, sc.description, sc.lambda, sc.rho, sc.mu_on*1000, sc.mu_off*1000);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    % 지연 테이블
    fprintf('\n[지연 통계 (mean ± std)]\n');
    fprintf('┌──────────┬──────────┬─────────────────┬─────────────────┬─────────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Mean Delay      │ P50 Delay       │ P90 Delay       │\n');
    fprintf('├──────────┼──────────┼─────────────────┼─────────────────┼─────────────────┤\n');
    
    % Baseline 먼저 (T_hold 무관)
    [mean_avg, mean_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'delay.mean_ms');
    [p50_avg, p50_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'delay.p50_ms');
    [p90_avg, p90_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'delay.p90_ms');
    if ~isnan(mean_avg)
        fprintf('│ %4s     │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │\n', ...
            '-', 'Baseline', mean_avg, mean_std, p50_avg, p50_std, p90_avg, p90_std);
    end
    
    % M0, M1(5) (T_hold별)
    for th_idx = 1:length(thold_values)
        thold_ms = thold_values(th_idx);
        for m_idx = 2:length(method_labels)  % M0, M1(5)만
            method = method_labels{m_idx};
            [mean_avg, mean_std] = get_avg_metric(results, sc_name, thold_ms, method, 'delay.mean_ms');
            [p50_avg, p50_std] = get_avg_metric(results, sc_name, thold_ms, method, 'delay.p50_ms');
            [p90_avg, p90_std] = get_avg_metric(results, sc_name, thold_ms, method, 'delay.p90_ms');
            
            if ~isnan(mean_avg)
                fprintf('│ %4dms   │ %-8s │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │ %6.1f ± %5.1f  │\n', ...
                    thold_ms, method, mean_avg, mean_std, p50_avg, p50_std, p90_avg, p90_std);
            end
        end
    end
    fprintf('└──────────┴──────────┴─────────────────┴─────────────────┴─────────────────┘\n');
    
    % T_hold 통계 테이블
    fprintf('\n[T_hold 통계 (mean ± std)]\n');
    fprintf('┌──────────┬──────────┬─────────────────┬─────────────────┬─────────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Hit Rate        │ Phantoms        │ SA Phantom%%     │\n');
    fprintf('├──────────┼──────────┼─────────────────┼─────────────────┼─────────────────┤\n');
    
    % Baseline 먼저
    [sp_avg, sp_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'throughput.sa_phantom_rate');
    if ~isnan(sp_avg)
        fprintf('│ %4s     │ %-8s │ %8s        │ %8s        │ %5.1f%% ± %4.1f%% │\n', ...
            '-', 'Baseline', 'N/A', 'N/A', sp_avg*100, sp_std*100);
    end
    
    % M0, M1(5)
    for th_idx = 1:length(thold_values)
        thold_ms = thold_values(th_idx);
        for m_idx = 2:length(method_labels)  % M0, M1(5)만
            method = method_labels{m_idx};
            [hr_avg, hr_std] = get_avg_metric(results, sc_name, thold_ms, method, 'thold.hit_rate');
            [ph_avg, ph_std] = get_avg_metric(results, sc_name, thold_ms, method, 'thold.phantoms');
            [sp_avg, sp_std] = get_avg_metric(results, sc_name, thold_ms, method, 'throughput.sa_phantom_rate');
            
            if ~isnan(hr_avg) && hr_avg > 0
                fprintf('│ %4dms   │ %-8s │ %5.1f%% ± %4.1f%% │ %6.0f ± %5.0f  │ %5.1f%% ± %4.1f%% │\n', ...
                    thold_ms, method, hr_avg*100, hr_std*100, ph_avg, ph_std, sp_avg*100, sp_std*100);
            else
                fprintf('│ %4dms   │ %-8s │ %8s        │ %8s        │ %5.1f%% ± %4.1f%% │\n', ...
                    thold_ms, method, 'N/A', 'N/A', sp_avg*100, sp_std*100);
            end
        end
    end
    fprintf('└──────────┴──────────┴─────────────────┴─────────────────┴─────────────────┘\n');
    
    % 공정성 테이블
    fprintf('\n[공정성 & UORA (mean ± std)]\n');
    fprintf('┌──────────┬──────────┬─────────────────┬─────────────────┬─────────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Jain Index      │ Collision%%      │ Idle%%           │\n');
    fprintf('├──────────┼──────────┼─────────────────┼─────────────────┼─────────────────┤\n');
    
    % Baseline 먼저
    [jain_avg, jain_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'fairness.jain_index');
    [coll_avg, coll_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'uora.collision_slot_rate');
    [idle_avg, idle_std] = get_avg_metric(results, sc_name, 0, 'Baseline', 'uora.idle_rate');
    if ~isnan(jain_avg)
        fprintf('│ %4s     │ %-8s │ %5.4f ± %5.4f │ %5.1f%% ± %4.1f%% │ %5.1f%% ± %4.1f%% │\n', ...
            '-', 'Baseline', jain_avg, jain_std, coll_avg*100, coll_std*100, idle_avg*100, idle_std*100);
    end
    
    % M0, M1(5)
    for th_idx = 1:length(thold_values)
        thold_ms = thold_values(th_idx);
        for m_idx = 2:length(method_labels)  % M0, M1(5)만
            method = method_labels{m_idx};
            [jain_avg, jain_std] = get_avg_metric(results, sc_name, thold_ms, method, 'fairness.jain_index');
            [coll_avg, coll_std] = get_avg_metric(results, sc_name, thold_ms, method, 'uora.collision_slot_rate');
            [idle_avg, idle_std] = get_avg_metric(results, sc_name, thold_ms, method, 'uora.idle_rate');
            
            if ~isnan(jain_avg)
                fprintf('│ %4dms   │ %-8s │ %5.4f ± %5.4f │ %5.1f%% ± %4.1f%% │ %5.1f%% ± %4.1f%% │\n', ...
                    thold_ms, method, jain_avg, jain_std, coll_avg*100, coll_std*100, idle_avg*100, idle_std*100);
            end
        end
    end
    fprintf('└──────────┴──────────┴─────────────────┴─────────────────┴─────────────────┘\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 1: 시나리오별 지연 비교 (T_hold=50ms 기준)
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n[시각화 생성 중...]\n');

fig1 = figure('Position', [50, 50, 1600, 500], 'Name', 'Figure 1: 시나리오별 지연 비교');

% 1-1. Mean Delay
subplot(1, 3, 1);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.delay.mean_ms;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('Mean Delay (ms)');
title('평균 지연 (T\_hold=50ms)');
legend(method_labels, 'Location', 'northwest');
grid on;

% 1-2. P90 Delay
subplot(1, 3, 2);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.delay.p90_ms;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('P90 Delay (ms)');
title('P90 지연 (T\_hold=50ms)');
legend(method_labels, 'Location', 'northwest');
grid on;

% 1-3. 지연 CDF (T_hold=50ms, 시나리오 A)
subplot(1, 3, 3);
hold on;
colors = lines(length(method_labels));
for m_idx = 1:length(method_labels)
    r = get_result('A', 50, method_labels{m_idx});
    if ~isempty(r) && isfield(r.delay, 'all_ms')
        sorted_data = sort(r.delay.all_ms);
        n = length(sorted_data);
        plot(sorted_data, (1:n)/n, '-', 'LineWidth', 2, 'Color', colors(m_idx,:), ...
            'DisplayName', method_labels{m_idx});
    end
end
xlabel('Delay (ms)');
ylabel('CDF');
title('지연 CDF (시나리오 A, T\_hold=50ms)');
legend('Location', 'southeast');
grid on;
xlim([0, 500]);

sgtitle('Figure 1: 시나리오별 지연 비교', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig1, fullfile(output_dir, 'fig1_delay_by_scenario.png'));
fprintf('  저장: fig1_delay_by_scenario.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 2: T_hold에 따른 지연 변화 (with error bars)
%  ═══════════════════════════════════════════════════════════════════════════

fig2 = figure('Position', [100, 100, 1600, 500], 'Name', 'Figure 2: T_hold에 따른 지연');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    colors = lines(length(method_labels));
    
    for m_idx = 1:length(method_labels)
        method = method_labels{m_idx};
        delays_avg = zeros(1, length(thold_values));
        delays_std = zeros(1, length(thold_values));
        
        for th_idx = 1:length(thold_values)
            [avg, stdev] = get_avg_metric(results, sc_name, thold_values(th_idx), method, 'delay.mean_ms');
            delays_avg(th_idx) = avg;
            delays_std(th_idx) = stdev;
        end
        
        errorbar(thold_values, delays_avg, delays_std, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', colors(m_idx,:), 'DisplayName', method, 'CapSize', 8);
    end
    
    xlabel('T\_hold (ms)');
    ylabel('Mean Delay (ms)');
    title(sprintf('시나리오 %s: %s', sc_name, results.scenarios.(sc_name).description));
    legend('Location', 'northeast');
    grid on;
    xlim([25, 75]);
end

sgtitle('Figure 2: T\_hold에 따른 평균 지연 변화 (mean ± std)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig2, fullfile(output_dir, 'fig2_delay_vs_thold.png'));
fprintf('  저장: fig2_delay_vs_thold.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 3: T_hold 통계 (Hit Rate, Phantoms)
%  ═══════════════════════════════════════════════════════════════════════════

fig3 = figure('Position', [150, 150, 1600, 800], 'Name', 'Figure 3: T_hold 통계');

% 3-1~3-3: Hit Rate by scenario
for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    subplot(2, 3, sc_idx);
    
    data = zeros(length(thold_values), 2);  % M0, M1(5)
    for th_idx = 1:length(thold_values)
        for m_idx = 2:3  % M0, M1(5)
            r = get_result(sc_name, thold_values(th_idx), method_labels{m_idx});
            if ~isempty(r) && isfield(r, 'thold') && isfield(r.thold, 'hit_rate')
                data(th_idx, m_idx-1) = r.thold.hit_rate * 100;
            end
        end
    end
    
    bar(data);
    set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%dms', x), thold_values, 'UniformOutput', false));
    ylabel('Hit Rate (%)');
    title(sprintf('시나리오 %s: Hit Rate', sc_name));
    legend({'M0', 'M1(5)'}, 'Location', 'northwest');
    grid on;
    ylim([0, 100]);
end

% 3-4~3-6: Phantoms by scenario
for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    subplot(2, 3, sc_idx + 3);
    
    data = zeros(length(thold_values), 2);  % M0, M1(5)
    for th_idx = 1:length(thold_values)
        for m_idx = 2:3  % M0, M1(5)
            r = get_result(sc_name, thold_values(th_idx), method_labels{m_idx});
            if ~isempty(r) && isfield(r, 'thold') && isfield(r.thold, 'phantoms')
                data(th_idx, m_idx-1) = r.thold.phantoms;
            end
        end
    end
    
    bar(data);
    set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%dms', x), thold_values, 'UniformOutput', false));
    ylabel('Phantom Count');
    title(sprintf('시나리오 %s: Phantoms', sc_name));
    legend({'M0', 'M1(5)'}, 'Location', 'northwest');
    grid on;
end

sgtitle('Figure 3: T\_hold 통계', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig3, fullfile(output_dir, 'fig3_thold_stats.png'));
fprintf('  저장: fig3_thold_stats.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 4: Trade-off 분석 (Delay vs Phantom)
%  ═══════════════════════════════════════════════════════════════════════════

fig4 = figure('Position', [200, 200, 1600, 500], 'Name', 'Figure 4: Trade-off');

colors_sc = lines(length(scenario_names));

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % Baseline 지연 (기준선)
    r_base = get_result(sc_name, 0, 'Baseline');
    if ~isempty(r_base)
        yline(r_base.delay.mean_ms, 'k--', 'LineWidth', 2);
        text(1000, r_base.delay.mean_ms + 5, 'Baseline', 'FontSize', 10);
    end
    
    % M0 포인트들
    for th_idx = 1:length(thold_values)
        r = get_result(sc_name, thold_values(th_idx), 'M0');
        if ~isempty(r) && isfield(r, 'thold') && isfield(r.thold, 'phantoms')
            scatter(r.thold.phantoms, r.delay.mean_ms, 150, 'b', 'filled', 'o');
            text(r.thold.phantoms * 1.02, r.delay.mean_ms, ...
                sprintf('M0 T%d', thold_values(th_idx)), 'FontSize', 9, 'Color', 'b');
        end
    end
    
    % M1(5) 포인트들
    for th_idx = 1:length(thold_values)
        r = get_result(sc_name, thold_values(th_idx), 'M1(5)');
        if ~isempty(r) && isfield(r, 'thold') && isfield(r.thold, 'phantoms')
            scatter(r.thold.phantoms, r.delay.mean_ms, 150, 'r', 'filled', 's');
            text(r.thold.phantoms * 1.02, r.delay.mean_ms, ...
                sprintf('M1 T%d', thold_values(th_idx)), 'FontSize', 9, 'Color', 'r');
        end
    end
    
    xlabel('Phantom Count');
    ylabel('Mean Delay (ms)');
    title(sprintf('시나리오 %s: Delay vs Phantom', sc_name));
    grid on;
end

sgtitle('Figure 4: Trade-off 분석 (Delay vs Phantom)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig4, fullfile(output_dir, 'fig4_tradeoff.png'));
fprintf('  저장: fig4_tradeoff.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 5: 공정성 & 처리율
%  ═══════════════════════════════════════════════════════════════════════════

fig5 = figure('Position', [250, 250, 1600, 500], 'Name', 'Figure 5: 공정성 & 처리율');

% 5-1: Jain's Fairness Index (T_hold=50ms)
subplot(1, 3, 1);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.fairness.jain_index;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('Jain''s Fairness Index');
title('공정성 (T\_hold=50ms)');
legend(method_labels, 'Location', 'southwest');
ylim([0.85, 1.0]);
grid on;

% 5-2: SA Phantom Rate (T_hold=50ms)
subplot(1, 3, 2);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.throughput.sa_phantom_rate * 100;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('SA Phantom Rate (%)');
title('SA-RU 낭비율 (T\_hold=50ms)');
legend(method_labels, 'Location', 'northwest');
grid on;

% 5-3: Throughput (T_hold=50ms)
subplot(1, 3, 3);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.throughput.total_mbps;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('Throughput (Mbps)');
title('처리율 (T\_hold=50ms)');
legend(method_labels, 'Location', 'southwest');
grid on;

sgtitle('Figure 5: 공정성 & 처리율', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig5, fullfile(output_dir, 'fig5_fairness_throughput.png'));
fprintf('  저장: fig5_fairness_throughput.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 6: 패킷 분류 (T_hold=50ms)
%  ═══════════════════════════════════════════════════════════════════════════

fig6 = figure('Position', [300, 300, 1600, 500], 'Name', 'Figure 6: 패킷 분류');

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    data = zeros(length(method_labels), 3);  % T_hold Hit, SA Queue, UORA Used
    for m_idx = 1:length(method_labels)
        r = get_result(sc_name, 50, method_labels{m_idx});
        if ~isempty(r)
            data(m_idx, :) = [r.pkt_class.thold_hit.ratio*100, ...
                             r.pkt_class.sa_queue.ratio*100, ...
                             r.pkt_class.uora_used.ratio*100];
        end
    end
    
    bar(data, 'stacked');
    set(gca, 'XTickLabel', method_labels);
    ylabel('Ratio (%)');
    title(sprintf('시나리오 %s: 패킷 분류', sc_name));
    legend({'T\_hold Hit', 'SA Queue', 'UORA Used'}, 'Location', 'eastoutside');
    ylim([0, 100]);
    grid on;
end

sgtitle('Figure 6: 패킷 분류 (T\_hold=50ms)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig6, fullfile(output_dir, 'fig6_pkt_class.png'));
fprintf('  저장: fig6_pkt_class.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 7: UORA 통계 (T_hold=50ms)
%  ═══════════════════════════════════════════════════════════════════════════

fig7 = figure('Position', [350, 350, 1600, 500], 'Name', 'Figure 7: UORA 통계');

% 7-1: Collision Rate
subplot(1, 3, 1);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.uora.collision_slot_rate * 100;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('Collision Rate (%)');
title('UORA Collision Rate (T\_hold=50ms)');
legend(method_labels, 'Location', 'northwest');
grid on;

% 7-2: Idle Rate
subplot(1, 3, 2);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.uora.idle_rate * 100;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('Idle Rate (%)');
title('UORA Idle Rate (T\_hold=50ms)');
legend(method_labels, 'Location', 'northwest');
grid on;

% 7-3: BSR Explicit Ratio
subplot(1, 3, 3);
data = zeros(length(scenario_names), length(method_labels));
for sc_idx = 1:length(scenario_names)
    for m_idx = 1:length(method_labels)
        r = get_result(scenario_names{sc_idx}, 50, method_labels{m_idx});
        if ~isempty(r)
            data(sc_idx, m_idx) = r.bsr.explicit_ratio * 100;
        end
    end
end
bar(data);
set(gca, 'XTickLabel', scenario_names);
ylabel('Explicit BSR Ratio (%)');
title('BSR Explicit Ratio (T\_hold=50ms)');
legend(method_labels, 'Location', 'northwest');
grid on;

sgtitle('Figure 7: UORA & BSR 통계', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig7, fullfile(output_dir, 'fig7_uora_bsr.png'));
fprintf('  저장: fig7_uora_bsr.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 8: Baseline 대비 개선율 (with error bars)
%  ═══════════════════════════════════════════════════════════════════════════

fig8 = figure('Position', [400, 400, 1200, 500], 'Name', 'Figure 8: 개선율');

% 데이터 준비: 시나리오 × T_hold × Method
improvement_avg = [];
improvement_std = [];
labels_x = {};
group_idx = 0;

for sc_idx = 1:length(scenario_names)
    sc_name = scenario_names{sc_idx};
    [base_delay, ~] = get_avg_metric(results, sc_name, 0, 'Baseline', 'delay.mean_ms');
    
    if ~isnan(base_delay)
        for th_idx = 1:length(thold_values)
            group_idx = group_idx + 1;
            labels_x{group_idx} = sprintf('%s T%d', sc_name, thold_values(th_idx));
            
            % M0
            [m0_delay, m0_std] = get_avg_metric(results, sc_name, thold_values(th_idx), 'M0', 'delay.mean_ms');
            improvement_avg(group_idx, 1) = -(m0_delay - base_delay) / base_delay * 100;
            improvement_std(group_idx, 1) = m0_std / base_delay * 100;
            
            % M1(5)
            [m1_delay, m1_std] = get_avg_metric(results, sc_name, thold_values(th_idx), 'M1(5)', 'delay.mean_ms');
            improvement_avg(group_idx, 2) = -(m1_delay - base_delay) / base_delay * 100;
            improvement_std(group_idx, 2) = m1_std / base_delay * 100;
        end
    end
end

% Grouped bar with error bars
ngroups = size(improvement_avg, 1);
nbars = size(improvement_avg, 2);
groupwidth = min(0.8, nbars/(nbars + 1.5));

hold on;
b = bar(improvement_avg);
b(1).FaceColor = [0.2 0.4 0.8];
b(2).FaceColor = [0.8 0.2 0.2];

% Error bars
for i = 1:nbars
    x = (1:ngroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
    errorbar(x, improvement_avg(:,i), improvement_std(:,i), 'k', 'LineStyle', 'none', 'CapSize', 5);
end

set(gca, 'XTickLabel', labels_x);
xtickangle(45);
ylabel('지연 개선율 (%)');
title('Baseline 대비 평균 지연 개선율 (mean ± std)');
legend({'M0', 'M1(5)'}, 'Location', 'northwest');
grid on;
yline(0, 'k-', 'LineWidth', 1);

sgtitle('Figure 8: Baseline 대비 개선율', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig8, fullfile(output_dir, 'fig8_improvement.png'));
fprintf('  저장: fig8_improvement.png\n');

fprintf('\n분석 완료! Figure 8개 저장됨.\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  헬퍼 함수 정의
%  ═══════════════════════════════════════════════════════════════════════════

function r = get_run_result(results, scenario, thold_ms, method)
    % 결과 구조체에서 특정 run 찾기 (첫 번째 seed 결과)
    r = [];
    
    % 필드명 생성 (seed_idx = 1)
    method_field = strrep(method, '(', '_');
    method_field = strrep(method_field, ')', '');
    
    % Baseline은 T_hold 없이 저장됨
    if strcmp(method, 'Baseline')
        field_name = sprintf('%s_Baseline_s1', scenario);
    else
        field_name = sprintf('%s_T%d_%s_s1', scenario, thold_ms, method_field);
    end
    
    if isfield(results.runs, field_name)
        r = results.runs.(field_name);
    end
end

function [avg, stdev] = get_avg_metric(results, scenario, thold_ms, method, metric_path)
    % 3회 반복의 평균과 표준편차 계산
    % metric_path: 예) 'delay.mean_ms', 'thold.hit_rate'
    
    num_seeds = results.meta.num_repeats;
    values = [];
    
    method_field = strrep(method, '(', '_');
    method_field = strrep(method_field, ')', '');
    
    for seed_idx = 1:num_seeds
        % Baseline은 T_hold 없이 저장됨
        if strcmp(method, 'Baseline')
            field_name = sprintf('%s_Baseline_s%d', scenario, seed_idx);
        else
            field_name = sprintf('%s_T%d_%s_s%d', scenario, thold_ms, method_field, seed_idx);
        end
        
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            
            % metric_path 파싱해서 값 추출
            parts = strsplit(metric_path, '.');
            val = r;
            valid = true;
            for i = 1:length(parts)
                if isfield(val, parts{i})
                    val = val.(parts{i});
                else
                    valid = false;
                    break;
                end
            end
            
            if valid
                values(end+1) = val;
            end
        end
    end
    
    if isempty(values)
        avg = NaN;
        stdev = NaN;
    else
        avg = mean(values);
        stdev = std(values);
    end
end