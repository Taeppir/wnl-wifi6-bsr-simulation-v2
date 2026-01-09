%% analyze_uora_delay_ratio.m
% 문제 제기용: Baseline에서 UORA 경쟁이 전체 지연의 몇 %인지 시각화
% 서론용 - 시나리오 구분 없이 전체 평균

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║         UORA 경쟁 지연 비율 분석 (문제 제기용)                    ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 데이터 로드
load('results/main_m0_m1_final/results.mat', 'results');
fprintf('[데이터 로드 완료]\n\n');

%% 설정
scenarios = {'A', 'B', 'C'};
num_seeds = 5;

output_dir = 'results/figures_delay';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% 데이터 수집 - Baseline 전체 평균
fprintf('[Baseline 지연 분해 분석]\n\n');

init_all = [];
uora_all = [];
sa_all = [];

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    
    for s = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc, s);
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            
            if isfield(r, 'delay_decomp')
                if isfield(r.delay_decomp, 'initial_wait') && isfield(r.delay_decomp.initial_wait, 'mean_ms')
                    init_all = [init_all; r.delay_decomp.initial_wait.mean_ms];
                end
                if isfield(r.delay_decomp, 'uora_contention') && isfield(r.delay_decomp.uora_contention, 'mean_ms')
                    uora_all = [uora_all; r.delay_decomp.uora_contention.mean_ms];
                end
                if isfield(r.delay_decomp, 'sa_wait') && isfield(r.delay_decomp.sa_wait, 'mean_ms')
                    sa_all = [sa_all; r.delay_decomp.sa_wait.mean_ms];
                end
            end
        end
    end
end

% 전체 평균
init_avg = mean(init_all);
uora_avg = mean(uora_all);
sa_avg = mean(sa_all);
total_avg = init_avg + uora_avg + sa_avg;
uora_ratio = uora_avg / total_avg * 100;

fprintf('전체 평균:\n');
fprintf('  Initial Wait:     %6.2f ms (%5.1f%%)\n', init_avg, init_avg/total_avg*100);
fprintf('  UORA Contention:  %6.2f ms (%5.1f%%)\n', uora_avg, uora_ratio);
fprintf('  SA Wait:          %6.2f ms (%5.1f%%)\n', sa_avg, sa_avg/total_avg*100);
fprintf('  ─────────────────────────────\n');
fprintf('  Total:            %6.2f ms (100%%)\n\n', total_avg);

%% Figure: 가로 Stacked Bar (서론용)
figure('Name', 'UORA Delay Ratio', 'Position', [100 100 550 120]);

% 색상 (진하게)
bar_colors = [0.3 0.5 0.7;    % TF 대기 - 진한 파랑
              0.85 0.35 0.15; % UORA - 진한 주황/빨강
              0.3 0.65 0.45]; % SA 대기 - 진한 초록

data = [init_avg, uora_avg, sa_avg];

% 가로 막대 - 두께 줄임
b = barh(1, data, 'stacked', 'BarWidth', 0.35);
b(1).FaceColor = bar_colors(1,:);
b(2).FaceColor = bar_colors(2,:);
b(3).FaceColor = bar_colors(3,:);

set(gca, 'YTick', [], 'FontSize', 10);
xlabel('Delay (ms)', 'FontSize', 11);
ylim([0.6 1.4]);
xlim([0 total_avg * 1.1]);

% 범례 - 오른쪽에 세로로 배치
pct_init = init_avg / total_avg * 100;
pct_sa = sa_avg / total_avg * 100;
lgd = legend({sprintf('TF 대기 (%.1f%%)', pct_init), ...
              sprintf('UORA 경쟁 (%.1f%%)', uora_ratio), ...
              sprintf('SA 스케줄링 대기 (%.1f%%)', pct_sa)}, ...
    'Location', 'eastoutside', 'FontSize', 8);

grid on;
set(gca, 'XGrid', 'on', 'YGrid', 'off');
%% 저장 (PDF + PNG)
exportgraphics(gcf, fullfile(output_dir, 'uora_delay_ratio.pdf'), 'ContentType', 'vector');
exportgraphics(gcf, fullfile(output_dir, 'uora_delay_ratio.png'), 'Resolution', 300);
fprintf('\n[저장 완료] %s/uora_delay_ratio.pdf / .png\n', output_dir);