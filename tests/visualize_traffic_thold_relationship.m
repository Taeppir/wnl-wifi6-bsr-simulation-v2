%% visualize_traffic_thold_relationship.m
% 트래픽 파라미터 (rho, mu_on, lambda, L_cell)와 T_hold 관계 시각화
%
% 발표용: T_hold가 언제 효과적인지 직관적으로 설명

clear; clc;

%% ═══════════════════════════════════════════════════════════════════
%  파라미터 설명 표
%  ═══════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║              Pareto On/Off 트래픽 모델 파라미터                        ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  파라미터     │ 의미                      │ 단위    │ 기본값        ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  lambda (λ)  │ ON 기간 패킷 생성률        │ pkt/s   │ 50           ║\n');
fprintf('║  mu_on       │ 평균 ON 기간              │ 초      │ 0.05 (50ms)  ║\n');
fprintf('║  mu_off      │ 평균 OFF 기간             │ 초      │ rho에 따름    ║\n');
fprintf('║  rho (ρ)     │ 활성 비율                 │ -       │ 0.5          ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  관계식:                                                             ║\n');
fprintf('║    ρ = μ_on / (μ_on + μ_off)                                        ║\n');
fprintf('║    μ_off = μ_on × (1 - ρ) / ρ                                       ║\n');
fprintf('║    단말당 평균 생성률 = λ × ρ  (pkt/s)                               ║\n');
fprintf('║    셀 전체 부하 L_cell = N × λ × ρ  (pkt/s)                          ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════
%  설정
%  ═══════════════════════════════════════════════════════════════════

% 고정 파라미터
mu_on = 0.050;  % 50ms
lambda = 50;    % pkt/s
num_stas = 50;

% rho 범위
rho_values = 0.1:0.1:0.9;

% T_hold 값들
thold_values = [10, 20, 30, 50, 100];  % ms

%% ═══════════════════════════════════════════════════════════════════
%  rho에 따른 파라미터 변화 계산
%  ═══════════════════════════════════════════════════════════════════

mu_off_values = mu_on * (1 - rho_values) ./ rho_values;  % 초
per_sta_rate = lambda * rho_values;  % pkt/s
L_cell = num_stas * lambda * rho_values;  % pkt/s

%% ═══════════════════════════════════════════════════════════════════
%  표: rho별 파라미터 값
%  ═══════════════════════════════════════════════════════════════════

fprintf('╔═══════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  ρ별 트래픽 파라미터 (μ_on=50ms, λ=50pkt/s, N=%d)                             ║\n', num_stas);
fprintf('╠═══════════════════════════════════════════════════════════════════════════════╣\n');
fprintf('║   ρ   │  μ_off (ms) │ 단말당 (pkt/s) │ L_cell (pkt/s) │ T_hold 권장         ║\n');
fprintf('╠═══════════════════════════════════════════════════════════════════════════════╣\n');

for i = 1:length(rho_values)
    rho = rho_values(i);
    mu_off = mu_off_values(i) * 1000;  % ms
    per_sta = per_sta_rate(i);
    Lcell = L_cell(i);
    
    % T_hold 권장값 (mu_off의 50-100%)
    thold_rec_min = mu_off * 0.5;
    thold_rec_max = mu_off * 1.0;
    
    fprintf('║  %.1f  │  %7.1f    │     %5.1f      │     %6.0f     │ %4.0f ~ %4.0f ms     ║\n', ...
        rho, mu_off, per_sta, Lcell, thold_rec_min, thold_rec_max);
end
fprintf('╚═══════════════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════
%  그래프 생성
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [50, 50, 1400, 900]);
sgtitle(sprintf('트래픽 파라미터와 T_{hold} 관계 (μ_{on}=%dms, λ=%dpkt/s, N=%d)', ...
    mu_on*1000, lambda, num_stas), 'FontSize', 14);

% 1. rho vs mu_off
subplot(2, 3, 1);
plot(rho_values, mu_off_values * 1000, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
hold on;
% T_hold 기준선
for th = [30, 50]
    yline(th, '--', sprintf('T_{hold}=%dms', th), 'Color', [0.8 0.2 0.2], 'LineWidth', 1.5);
end
xlabel('\rho (활성 비율)');
ylabel('\mu_{off} (ms)');
title('\rho vs μ_{off}');
grid on;
xlim([0.1, 0.9]);

% 커버리지 영역 표시
text(0.7, 150, 'T_{hold} < μ_{off}: 효과적', 'FontSize', 10, 'Color', [0 0.5 0]);
text(0.7, 30, 'T_{hold} > μ_{off}: Phantom 위험', 'FontSize', 10, 'Color', [0.8 0 0]);

% 2. rho vs 단말당 생성률 & L_cell
subplot(2, 3, 2);
yyaxis left;
plot(rho_values, per_sta_rate, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
ylabel('단말당 생성률 (pkt/s)');
yyaxis right;
plot(rho_values, L_cell, 'r-s', 'LineWidth', 2, 'MarkerFaceColor', 'r');
ylabel('L_{cell} (pkt/s)');
xlabel('\rho');
title('트래픽 부하');
legend('단말당', 'L_{cell}', 'Location', 'northwest');
grid on;
xlim([0.1, 0.9]);

% 3. T_hold 커버리지 맵
subplot(2, 3, 3);
[RHO, THOLD] = meshgrid(rho_values, thold_values);
MU_OFF = mu_on * 1000 * (1 - RHO) ./ RHO;  % ms
COVERAGE = THOLD ./ MU_OFF * 100;

imagesc(rho_values, thold_values, COVERAGE);
set(gca, 'YDir', 'normal');
colorbar;
colormap(jet);
caxis([0, 200]);
xlabel('\rho');
ylabel('T_{hold} (ms)');
title('T_{hold} / μ_{off} 커버리지 (%)');

% 100% 등고선 추가
hold on;
contour(RHO, THOLD, COVERAGE, [100 100], 'k-', 'LineWidth', 2);
text(0.5, 60, '100% 경계', 'FontSize', 10, 'FontWeight', 'bold');

% 4. 패킷 생성 패턴 시각화 (rho별)
subplot(2, 3, 4);
t = 0:0.001:0.5;  % 500ms 동안

rho_examples = [0.3, 0.5, 0.7];
colors = {'b', 'g', 'r'};

hold on;
for i = 1:length(rho_examples)
    rho = rho_examples(i);
    mu_off = mu_on * (1 - rho) / rho;
    
    % 단순화된 On/Off 패턴 시각화
    cycle = mu_on + mu_off;
    pattern = mod(t, cycle) < mu_on;
    
    plot(t * 1000, pattern * 0.8 + (i-1), colors{i}, 'LineWidth', 2);
end

% T_hold 표시
for th = [30, 50] / 1000
    xline(th * 1000, '--', sprintf('T=%dms', th*1000), 'Color', [0.5 0.5 0.5]);
end

yticks([0.4, 1.4, 2.4]);
yticklabels({'\rho=0.3', '\rho=0.5', '\rho=0.7'});
xlabel('Time (ms)');
title('On/Off 패턴 (μ_{on}=50ms 고정)');
xlim([0, 300]);
ylim([-0.2, 3]);
grid on;

% 설명 추가
text(200, 0.4, sprintf('μ_{off}=%.0fms', mu_on*1000*(1-0.3)/0.3), 'FontSize', 9);
text(200, 1.4, sprintf('μ_{off}=%.0fms', mu_on*1000*(1-0.5)/0.5), 'FontSize', 9);
text(200, 2.4, sprintf('μ_{off}=%.0fms', mu_on*1000*(1-0.7)/0.7), 'FontSize', 9);

% 5. 예상 Hit Rate 곡선 (이론적)
subplot(2, 3, 5);
coverage_pct = 0:5:200;
% 단순 모델: Hit Rate ≈ 1 - exp(-coverage/100) for coverage <= 100
%            saturates after 100%
hit_rate_model = min(coverage_pct / 100, 1) * 100;  % 선형 근사
hit_rate_exp = (1 - exp(-coverage_pct / 80)) * 100;  % 지수 근사

plot(coverage_pct, hit_rate_model, 'b-', 'LineWidth', 2);
hold on;
plot(coverage_pct, hit_rate_exp, 'r--', 'LineWidth', 2);
xline(100, 'k--', 'LineWidth', 1.5);
xlabel('T_{hold} / μ_{off} 커버리지 (%)');
ylabel('예상 Hit Rate (%)');
title('커버리지 vs Hit Rate (이론)');
legend('선형 모델', '지수 모델', '100% 경계', 'Location', 'southeast');
grid on;
xlim([0, 200]);
ylim([0, 110]);

% 6. Trade-off 요약
subplot(2, 3, 6);
axis off;

text_content = {
    '═══════════════════════════════════════════════'
    '             T_{hold} Trade-off 요약            '
    '═══════════════════════════════════════════════'
    ''
    '▶ T_{hold} 효과 조건:'
    '   • T_{hold} ≈ μ_{off} 일 때 최적'
    '   • 커버리지 50-100%가 이상적'
    ''
    '▶ rho가 낮을 때 (0.2~0.4):'
    '   • μ_{off}가 김 (75~200ms)'
    '   • 큰 T_{hold} 필요 (50ms+)'
    '   • Hit Rate 낮을 수 있음'
    ''
    '▶ rho가 높을 때 (0.6~0.8):'
    '   • μ_{off}가 짧음 (12~33ms)'
    '   • 작은 T_{hold}로 충분 (20~30ms)'
    '   • 과도한 T_{hold}는 Phantom 유발'
    ''
    '▶ 최적 전략:'
    '   T_{hold} = 0.5 ~ 1.0 × μ_{off}'
    '═══════════════════════════════════════════════'
};

text(0.05, 0.95, text_content, 'FontSize', 10, 'FontName', 'FixedWidth', ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');

% 저장
if ~exist('results/figures', 'dir')
    mkdir('results/figures');
end
saveas(gcf, 'results/figures/traffic_thold_relationship.png');
saveas(gcf, 'results/figures/traffic_thold_relationship.fig');
fprintf('그래프 저장: results/figures/traffic_thold_relationship.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  L_cell 계산 예시
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  L_cell (셀 전체 부하) 계산 예시                                      ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║                                                                      ║\n');
fprintf('║  L_cell = N × λ × ρ                                                 ║\n');
fprintf('║                                                                      ║\n');
fprintf('║  예시 1: N=50, λ=50, ρ=0.5                                          ║\n');
fprintf('║          L_cell = 50 × 50 × 0.5 = 1250 pkt/s                        ║\n');
fprintf('║          = 1250 × 2000 × 8 = 20 Mbps                                ║\n');
fprintf('║                                                                      ║\n');
fprintf('║  예시 2: N=20, λ=100, ρ=0.3                                         ║\n');
fprintf('║          L_cell = 20 × 100 × 0.3 = 600 pkt/s                        ║\n');
fprintf('║          = 600 × 2000 × 8 = 9.6 Mbps                                ║\n');
fprintf('║                                                                      ║\n');
fprintf('║  * 같은 L_cell이어도 rho에 따라 버스트 특성이 다름!                    ║\n');
fprintf('║  * 낮은 rho = 긴 OFF 구간 = T_hold 효과 ↓                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n');

%% ═══════════════════════════════════════════════════════════════════
%  실험 설정과의 연관성
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  실험 설정 기준 T_{hold} 권장값                                       ║\n');
fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
fprintf('║                                                                      ║\n');
fprintf('║  현재 설정: μ_on = 50ms                                              ║\n');
fprintf('║                                                                      ║\n');
fprintf('║   ρ    │  μ_off  │ T_hold 권장 │ Phase 3 실험값                    ║\n');
fprintf('║────────┼─────────┼─────────────┼────────────────────────────────────║\n');

phase3_rho = [0.2, 0.4, 0.6, 0.8];
phase3_thold = [30, 50];

for rho = phase3_rho
    mu_off = mu_on * 1000 * (1 - rho) / rho;
    thold_rec = sprintf('%.0f~%.0fms', mu_off * 0.5, mu_off);
    thold_test = sprintf('%d, %dms', phase3_thold(1), phase3_thold(2));
    
    % 커버리지 확인
    cov1 = phase3_thold(1) / mu_off * 100;
    cov2 = phase3_thold(2) / mu_off * 100;
    
    fprintf('║  %.1f   │ %5.0fms │ %11s │ %s (%.0f%%, %.0f%% 커버)       ║\n', ...
        rho, mu_off, thold_rec, thold_test, cov1, cov2);
end

fprintf('║                                                                      ║\n');
fprintf('║  → ρ=0.2에서 T_hold=50ms는 25% 커버 (효과 제한적)                    ║\n');
fprintf('║  → ρ=0.8에서 T_hold=50ms는 400% 커버 (Phantom 위험)                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n');