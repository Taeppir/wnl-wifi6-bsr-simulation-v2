%% analyze_saru_utilization.m
% SA-RU 활용률 막대그래프 (시나리오별 1x3)
% 
% SA-RU 활용률 = SA-RU 전송 성공 / SA-RU 할당 횟수
%            = 1 - Phantom Rate

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║            SA-RU 활용률 분석                                      ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 데이터 로드
m0m1_file = 'results/main_m0_m1_final/results.mat';
m2_file = 'results/main_m2_final/results.mat';

load(m0m1_file, 'results'); results_m0m1 = results;
load(m2_file, 'results'); results_m2 = results;
fprintf('[데이터 로드 완료]\n\n');

%% 설정
scenarios = {'A', 'B', 'C'};
scenario_desc = {'VoIP-like (21%)', 'Video-like (69%)', 'IoT-like (42%)'};
thold_values = [30, 50, 70];
num_seeds = 10;

% 색상 (지연 그래프와 동일하게)
colors.Baseline = [0.5 0.5 0.5];           % 회색 - 기존 방식
colors.M0 = [0.3 0.5 0.8];                 % 파랑 - 기법 1
colors.M1 = [0.95 0.7 0.2];                % 주황 - 기법 2
colors.M2 = [0.4 0.7 0.4];                 % 초록 - 기법 3

output_dir = 'results/figures_delay';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Figure: SA-RU 활용률 (1x3 - 시나리오별)
figure('Name', 'SA-RU Utilization', 'Position', [100 100 1500 450]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    
    % 데이터 수집: Base(1개) + M0(3개) + M1(3개) + M2(3개) = 10개 막대
    util_data = zeros(1, 10);
    
    % Baseline (T_hold 무관)
    util_data(1) = get_util(results_m0m1, sc, 0, 'Baseline', num_seeds) * 100;
    
    % M0: T30, T50, T70
    for th_idx = 1:3
        util_data(1 + th_idx) = get_util(results_m0m1, sc, thold_values(th_idx), 'M0', num_seeds) * 100;
    end
    
    % M1: T30, T50, T70
    for th_idx = 1:3
        util_data(4 + th_idx) = get_util(results_m0m1, sc, thold_values(th_idx), 'M1(5)', num_seeds) * 100;
    end
    
    % M2: T30, T50, T70
    for th_idx = 1:3
        util_data(7 + th_idx) = get_util(results_m2, sc, thold_values(th_idx), 'M2', num_seeds) * 100;
    end
    
    % 막대 색상
    bar_colors = [colors.Baseline;  % Base
                  colors.M0; colors.M0; colors.M0;  % M0
                  colors.M1; colors.M1; colors.M1;  % M1
                  colors.M2; colors.M2; colors.M2]; % M2
    
    % 막대 그리기
    hold on;
    for i = 1:10
        bar(i, util_data(i), 'FaceColor', bar_colors(i,:), 'EdgeColor', 'k');
        if util_data(i) > 0
            text(i, util_data(i) + 2, sprintf('%.0f', util_data(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end
    end
    
    % 그룹 구분선
    xline(1.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    xline(4.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    xline(7.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    
    hold off;
    
    % x축 레이블
    set(gca, 'XTick', 1:10, ...
        'XTickLabel', {'기존', '30', '50', '70', '30', '50', '70', '30', '50', '70'}, ...
        'FontSize', 8);
    
    % 그룹 레이블 (하단)
    text(1, -12, '기존 방식', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.Baseline);
    text(3, -12, '기법 1', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.M0);
    text(6, -12, '기법 2', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.M1);
    text(9, -12, '기법 3', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', colors.M2);
    
    ylabel('SA-RU Utilization (%)', 'FontSize', 10);
    title(sprintf('시나리오 %s', sc), 'FontSize', 11);
    ylim([0 115]);
    xlim([0.3 10.7]);
    grid on;
    set(gca, 'YGrid', 'on', 'XGrid', 'off');
end

%% 저장
saveas(gcf, fullfile(output_dir, 'saru_utilization.png'));
fprintf('[저장 완료] %s/saru_utilization.png\n', output_dir);

%% Figure 2: 꺾은선 그래프 (T_hold별 추이)
figure('Name', 'SA-RU Utilization Line', 'Position', [100 100 1400 400]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    
    % Baseline (T_hold 무관, 점선으로 표시)
    u_base = get_util(results_m0m1, sc, 0, 'Baseline', num_seeds) * 100;
    
    % M0, M1, M2 각 T_hold별
    u_m0 = zeros(1, 3);
    u_m1 = zeros(1, 3);
    u_m2 = zeros(1, 3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        u_m0(th_idx) = get_util(results_m0m1, sc, th, 'M0', num_seeds) * 100;
        u_m1(th_idx) = get_util(results_m0m1, sc, th, 'M1(5)', num_seeds) * 100;
        u_m2(th_idx) = get_util(results_m2, sc, th, 'M2', num_seeds) * 100;
    end
    
    hold on;
    % Baseline 점선
    yline(u_base, '--', 'Color', colors.Baseline, 'LineWidth', 2);
    
    % M0, M1, M2 꺾은선
    plot(thold_values, u_m0, '-o', 'Color', colors.M0, 'LineWidth', 2, ...
        'MarkerSize', 10, 'MarkerFaceColor', colors.M0);
    plot(thold_values, u_m1, '-s', 'Color', colors.M1, 'LineWidth', 2, ...
        'MarkerSize', 10, 'MarkerFaceColor', colors.M1);
    plot(thold_values, u_m2, '-^', 'Color', colors.M2, 'LineWidth', 2, ...
        'MarkerSize', 10, 'MarkerFaceColor', colors.M2);
    
    % 값 표시 제거 - 그래프만으로 충분
    hold off;
    
    xlabel('T_{hold} (ms)', 'FontSize', 11);
    ylabel('SA-RU Utilization (%)', 'FontSize', 11);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([25 75]);
    ylim([0 110]);
    set(gca, 'XTick', thold_values);
    grid on;
    
    if sc_idx == 2
        legend({'기존 방식', '기법 1', '기법 2', '기법 3'}, 'Location', 'southwest', 'FontSize', 9);
    end
end

%% 저장 (꺾은선)
saveas(gcf, fullfile(output_dir, 'saru_utilization_line.png'));
fprintf('[저장 완료] %s/saru_utilization_line.png\n', output_dir);

%% ═══════════════════════════════════════════════════════════════════════════
%  Helper Function
%  ═══════════════════════════════════════════════════════════════════════════

function util_mean = get_util(results, scenario, thold_ms, method, num_seeds)
    utils = [];
    
    for s = 1:num_seeds
        % 필드 이름 생성
        if strcmp(method, 'Baseline')
            field_name = sprintf('%s_Baseline_s%d', scenario, s);
        elseif strcmp(method, 'M1(5)')
            field_name = sprintf('%s_T%d_M1_5_s%d', scenario, thold_ms, s);
        else
            field_name = sprintf('%s_T%d_%s_s%d', scenario, thold_ms, method, s);
        end
        
        if ~isfield(results.runs, field_name)
            continue;
        end
        
        r = results.runs.(field_name);
        util = NaN;
        
        % 방법 1: throughput.sa_utilization
        if isfield(r, 'throughput') && isfield(r.throughput, 'sa_utilization')
            util = r.throughput.sa_utilization;
        % 방법 2: ru_utilization.sa_utilization  
        elseif isfield(r, 'ru_utilization') && isfield(r.ru_utilization, 'sa_utilization')
            util = r.ru_utilization.sa_utilization;
        % 방법 3: thold 통계에서 계산 (Baseline 제외)
        elseif isfield(r, 'thold') && isfield(r.thold, 'hits') && isfield(r.thold, 'phantoms')
            hits = r.thold.hits;
            phantoms = r.thold.phantoms;
            if (hits + phantoms) > 0
                util = hits / (hits + phantoms);
            end
        end
        
        % Baseline은 거의 100% (T_hold 없으므로 Phantom 없음)
        if strcmp(method, 'Baseline') && isnan(util)
            util = 1.0;
        end
        
        if ~isnan(util)
            utils = [utils; util];
        end
    end
    
    if isempty(utils)
        util_mean = NaN;
    else
        util_mean = mean(utils);
    end
end