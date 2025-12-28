%% analyze_all_phases.m
% Phase 1, 2, 3 결과 종합 분석
%
% 객관적 지표만 사용:
%   - 카운트: activations, hits, expirations, phantom
%   - 비율: hit_rate, sa_utilization, collision_rate
%   - 측정값: delay, throughput, completion

clear; clc;
addpath(genpath(pwd));

%% 데이터 로드
results_dir = 'results/summary';
figures_dir = 'results/figures';
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

try
    phase1 = readtable(fullfile(results_dir, 'phase1_baseline.csv'));
    phase2 = readtable(fullfile(results_dir, 'phase2_thold_sweep.csv'));
    phase3 = readtable(fullfile(results_dir, 'phase3_rho_sweep.csv'));
    fprintf('데이터 로드 완료: Phase1=%d, Phase2=%d, Phase3=%d\n', ...
        height(phase1), height(phase2), height(phase3));
catch
    fprintf('데이터 로드 실패. Phase 1, 2, 3 실험을 먼저 실행하세요.\n');
    return;
end

%% ═══════════════════════════════════════════════════════════════════
%  1. Phase 2: T_hold 값별 성능 비교 (rho=0.5)
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  1. T_hold 값별 성능 비교 (Phase 2, rho=0.5)                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

sta_list = unique(phase2.num_stas);
thold_list = unique(phase2.thold_ms);

% Baseline (Phase 1, rho=0.5) 추출
baseline_rho05 = phase1(abs(phase1.rho - 0.5) < 0.01, :);

fprintf('%-6s | %-8s | %10s | %10s | %10s | %10s | %10s\n', ...
    'STA', 'T_hold', 'Delay(ms)', 'Improve%', 'Complete%', 'Collision%', 'HitRate%');
fprintf('%s\n', repmat('-', 1, 80));

for si = 1:length(sta_list)
    sta = sta_list(si);
    
    % Baseline
    base_idx = baseline_rho05.num_stas == sta;
    if ~any(base_idx), continue; end
    base_delay = baseline_rho05.delay_mean_ms(base_idx);
    base_complete = baseline_rho05.completion_rate(base_idx);
    base_collision = baseline_rho05.uora_collision_rate(base_idx);
    
    fprintf('%-6d | %8s | %10.1f | %10s | %10.1f | %10.1f | %10s\n', ...
        sta, 'Baseline', base_delay, '-', base_complete*100, base_collision*100, '-');
    
    for ti = 1:length(thold_list)
        thold = thold_list(ti);
        
        idx = phase2.num_stas == sta & phase2.thold_ms == thold;
        if ~any(idx), continue; end
        
        delay = phase2.delay_mean_ms(idx);
        complete = phase2.completion_rate(idx);
        collision = phase2.uora_collision_rate(idx);
        hit_rate = phase2.thold_hit_rate(idx);
        
        improve = (base_delay - delay) / base_delay * 100;
        
        fprintf('%-6d | %6dms | %10.1f | %+9.1f%% | %10.1f | %10.1f | %10.1f\n', ...
            sta, thold, delay, improve, complete*100, collision*100, hit_rate*100);
    end
    fprintf('%s\n', repmat('-', 1, 80));
end

%% ═══════════════════════════════════════════════════════════════════
%  2. T_hold 상세 카운트 (Phase 2)
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  2. T_hold 상세 카운트 (Phase 2)                             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('%-6s | %-8s | %10s | %10s | %10s | %10s\n', ...
    'STA', 'T_hold', 'Activations', 'Hits', 'Expirations', 'Phantom');
fprintf('%s\n', repmat('-', 1, 70));

for i = 1:height(phase2)
    fprintf('%-6d | %6dms | %10d | %10d | %10d | %10d\n', ...
        phase2.num_stas(i), phase2.thold_ms(i), ...
        phase2.thold_activations(i), phase2.thold_hits(i), ...
        phase2.thold_expirations(i), phase2.thold_phantom_count(i));
end

%% ═══════════════════════════════════════════════════════════════════
%  3. Phase 3: rho별 T_hold 효과
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  3. rho별 T_hold 효과 (Phase 3)                              ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

rho_list = unique(phase3.rho);

fprintf('%-6s | %-6s | %10s | %10s | %10s | %10s | %10s\n', ...
    'STA', 'rho', 'Coverage%', 'BaseDelay', 'T_holdDelay', 'Improve%', 'HitRate%');
fprintf('%s\n', repmat('-', 1, 80));

for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        sta = sta_list(si);
        rho = rho_list(ri);
        
        % Baseline
        base_idx = phase1.num_stas == sta & abs(phase1.rho - rho) < 0.01;
        % T_hold
        thold_idx = phase3.num_stas == sta & abs(phase3.rho - rho) < 0.01;
        
        if any(base_idx) && any(thold_idx)
            base_delay = phase1.delay_mean_ms(base_idx);
            thold_delay = phase3.delay_mean_ms(thold_idx);
            coverage = phase3.thold_coverage(thold_idx);
            hit_rate = phase3.thold_hit_rate(thold_idx);
            
            improve = (base_delay - thold_delay) / base_delay * 100;
            
            fprintf('%-6d | %-6.1f | %10.0f | %10.1f | %10.1f | %+9.1f%% | %9.1f\n', ...
                sta, rho, coverage, base_delay, thold_delay, improve, hit_rate*100);
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════
%  4. RU 사용 현황
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  4. RU 사용 현황                                             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('■ SA-RU Utilization (Phase 2):\n');
fprintf('%-6s | %-8s | %15s\n', 'STA', 'T_hold', 'SA Utilization%');
fprintf('%s\n', repmat('-', 1, 40));

% Baseline SA utilization
for si = 1:length(sta_list)
    sta = sta_list(si);
    base_idx = baseline_rho05.num_stas == sta;
    if any(base_idx)
        fprintf('%-6d | %8s | %15.1f\n', ...
            sta, 'Baseline', baseline_rho05.sa_utilization(base_idx)*100);
    end
end

for i = 1:height(phase2)
    fprintf('%-6d | %6dms | %15.1f\n', ...
        phase2.num_stas(i), phase2.thold_ms(i), phase2.sa_utilization(i)*100);
end

%% ═══════════════════════════════════════════════════════════════════
%  5. 공정성 분석
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  5. 공정성 분석                                              ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('%-10s | %-6s | %-8s | %10s | %10s | %12s\n', ...
    'Phase', 'STA', 'rho/Thold', 'Jain Index', 'CoV', 'MinMax Ratio');
fprintf('%s\n', repmat('-', 1, 70));

% Phase 1
for i = 1:height(phase1)
    fprintf('%-10s | %-6d | rho=%.1f  | %10.4f | %10.4f | %12.4f\n', ...
        'Baseline', phase1.num_stas(i), phase1.rho(i), ...
        phase1.jain_index(i), phase1.cov(i), phase1.min_max_ratio(i));
end

% Phase 2
for i = 1:height(phase2)
    fprintf('%-10s | %-6d | %4dms   | %10.4f | %10.4f | %12.4f\n', ...
        'T_hold', phase2.num_stas(i), phase2.thold_ms(i), ...
        phase2.jain_index(i), phase2.cov(i), phase2.min_max_ratio(i));
end

%% ═══════════════════════════════════════════════════════════════════
%  6. 그래프 생성
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n■ 그래프 생성 중...\n');

% Figure 1: Delay 비교 (Phase 1 vs Phase 2)
fig1 = figure('Position', [100, 100, 900, 400]);

sta_example = sta_list(ceil(length(sta_list)/2));  % 중간 STA 선택
baseline_delay = phase1.delay_mean_ms(phase1.num_stas == sta_example & abs(phase1.rho - 0.5) < 0.01);

idx = phase2.num_stas == sta_example;
thold_vals = [0; phase2.thold_ms(idx)];
delay_vals = [baseline_delay; phase2.delay_mean_ms(idx)];
complete_vals = [phase1.completion_rate(phase1.num_stas == sta_example & abs(phase1.rho - 0.5) < 0.01); ...
                 phase2.completion_rate(idx)] * 100;

subplot(1,2,1);
bar(thold_vals, delay_vals, 0.6, 'FaceColor', [0.3 0.5 0.8]);
ylabel('Mean Delay (ms)');
xlabel('T_{hold} (ms)');
title(sprintf('STA=%d, rho=0.5: Delay', sta_example));
grid on;

subplot(1,2,2);
bar(thold_vals, complete_vals, 0.6, 'FaceColor', [0.3 0.7 0.3]);
ylabel('Completion Rate (%)');
xlabel('T_{hold} (ms)');
title(sprintf('STA=%d, rho=0.5: Completion', sta_example));
ylim([0 105]);
grid on;

saveas(fig1, fullfile(figures_dir, 'phase2_delay_completion.png'));
fprintf('  저장: phase2_delay_completion.png\n');

% Figure 2: T_hold 카운트
fig2 = figure('Position', [100, 550, 800, 400]);

idx = phase2.num_stas == sta_example;
thold_vals = phase2.thold_ms(idx);
hits = phase2.thold_hits(idx);
expirations = phase2.thold_expirations(idx);
phantom = phase2.thold_phantom_count(idx);

bar_data = [hits, expirations];
bar(thold_vals, bar_data, 0.8);
ylabel('Count');
xlabel('T_{hold} (ms)');
title(sprintf('STA=%d: T_hold Activation Results', sta_example));
legend('Hits (SA 전송 성공)', 'Expirations (만료)', 'Location', 'best');
grid on;

saveas(fig2, fullfile(figures_dir, 'phase2_thold_counts.png'));
fprintf('  저장: phase2_thold_counts.png\n');

% Figure 3: Coverage vs Hit Rate (Phase 3)
fig3 = figure('Position', [100, 1000, 700, 400]);

coverages = [];
hit_rates_fig = [];

for ri = 1:length(rho_list)
    rho = rho_list(ri);
    idx = abs(phase3.rho - rho) < 0.01;
    
    if any(idx)
        coverages(end+1) = mean(phase3.thold_coverage(idx));
        hit_rates_fig(end+1) = mean(phase3.thold_hit_rate(idx)) * 100;
    end
end

bar(coverages, hit_rates_fig, 0.6, 'FaceColor', [0.8 0.4 0.2]);
xlabel('Coverage (%)');
ylabel('Hit Rate (%)');
title('Coverage vs Hit Rate');
grid on;

saveas(fig3, fullfile(figures_dir, 'phase3_coverage_hitrate.png'));
fprintf('  저장: phase3_coverage_hitrate.png\n');

% Figure 4: Delay Improvement Heatmap (Phase 3)
fig4 = figure('Position', [800, 100, 700, 500]);

% 개선율 매트릭스 생성
improve_matrix = zeros(length(sta_list), length(rho_list));
for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        sta = sta_list(si);
        rho = rho_list(ri);
        
        base_idx = phase1.num_stas == sta & abs(phase1.rho - rho) < 0.01;
        thold_idx = phase3.num_stas == sta & abs(phase3.rho - rho) < 0.01;
        
        if any(base_idx) && any(thold_idx)
            base_delay = phase1.delay_mean_ms(base_idx);
            thold_delay = phase3.delay_mean_ms(thold_idx);
            improve_matrix(si, ri) = (base_delay - thold_delay) / base_delay * 100;
        end
    end
end

imagesc(improve_matrix);
colorbar;
colormap(jet);
set(gca, 'XTick', 1:length(rho_list), 'XTickLabel', arrayfun(@(x) sprintf('%.1f', x), rho_list, 'UniformOutput', false));
set(gca, 'YTick', 1:length(sta_list), 'YTickLabel', arrayfun(@(x) sprintf('%d', x), sta_list, 'UniformOutput', false));
xlabel('rho');
ylabel('Number of STAs');
title('Delay Improvement (%) with T_{hold}');

% 셀에 숫자 표시
for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        text(ri, si, sprintf('%.0f%%', improve_matrix(si, ri)), ...
            'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold');
    end
end

saveas(fig4, fullfile(figures_dir, 'phase3_improvement_heatmap.png'));
fprintf('  저장: phase3_improvement_heatmap.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  7. 요약
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  7. 요약                                                     ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

% Phase 2에서 최고 성능 찾기
fprintf('■ Phase 2 (rho=0.5) 최고 성능:\n');
for si = 1:length(sta_list)
    sta = sta_list(si);
    idx = phase2.num_stas == sta;
    
    if any(idx)
        sub_table = phase2(idx, :);
        [min_delay, best_idx] = min(sub_table.delay_mean_ms);
        best_thold = sub_table.thold_ms(best_idx);
        best_hit_rate = sub_table.thold_hit_rate(best_idx);
        best_complete = sub_table.completion_rate(best_idx);
        
        % Baseline 대비 개선율
        base_idx = baseline_rho05.num_stas == sta;
        base_delay = baseline_rho05.delay_mean_ms(base_idx);
        improve = (base_delay - min_delay) / base_delay * 100;
        
        fprintf('  STA=%d: T_hold=%dms → Delay %.1fms (%.0f%% 개선), HitRate %.1f%%, Complete %.1f%%\n', ...
            sta, best_thold, min_delay, improve, best_hit_rate*100, best_complete*100);
    end
end

fprintf('\n분석 완료. 그래프: results/figures/\n');