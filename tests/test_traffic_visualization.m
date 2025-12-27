%% test_traffic_viz.m
% Pareto ON/OFF 트래픽 모델 시각화
% OFF 구간에 패킷이 생성되지 않는지 확인

clear; clc;
addpath(genpath(pwd));

%% 설정
sim_time = 1;      % 0.5초 (짧게)
num_stas = 3;        % 3개 STA
lambda = 50;         % 50 pkt/s
mu_on = 0.05;        % 50ms ON
rho = 0.5;
mu_off = mu_on * (1 - rho) / rho;
seed = 12345;

fprintf('트래픽 시각화 테스트\n');
fprintf('═══════════════════════════════════════\n');
fprintf('시뮬레이션: %.2fs, STA: %d, λ=%d pkt/s\n', sim_time, num_stas, lambda);
fprintf('μ_on=%.0fms, μ_off=%.0fms, ρ=%.1f\n\n', mu_on*1000, mu_off*1000, rho);

%% 트래픽 생성 (TrafficGenerator와 동일 로직)
rng(seed);
traffic = cell(num_stas, 1);
pareto_alpha = 1.5;

for sta = 1:num_stas
    on_periods = [];
    off_periods = [];
    packets = [];
    
    t = 0;
    is_on = false;
    
    while t < sim_time
        % Pareto 분포로 기간 생성
        u = rand();
        if is_on
            dur = mu_on * (pareto_alpha - 1) / pareto_alpha * (1 - u)^(-1/pareto_alpha);
            dur = min(dur, sim_time - t);
            on_periods = [on_periods; t, t + dur];
            
            % ON 중 Poisson 패킷 생성
            pkt_t = t;
            while pkt_t < t + dur
                pkt_t = pkt_t + (-log(rand()) / lambda);
                if pkt_t < t + dur
                    packets = [packets; pkt_t];
                end
            end
            t = t + dur;
            is_on = false;
        else
            dur = mu_off * (pareto_alpha - 1) / pareto_alpha * (1 - u)^(-1/pareto_alpha);
            dur = min(dur, sim_time - t);
            off_periods = [off_periods; t, t + dur];
            t = t + dur;
            is_on = true;
        end
    end
    
    traffic{sta}.on = on_periods;
    traffic{sta}.off = off_periods;
    traffic{sta}.pkts = packets;
end

%% 시각화
figure('Position', [100, 100, 1200, 600]);

% 상단: ON/OFF 구간 + 패킷 도착
subplot(2,1,1);
hold on;

for sta = 1:num_stas
    % ON 구간 (녹색)
    for i = 1:size(traffic{sta}.on, 1)
        fill([traffic{sta}.on(i,1), traffic{sta}.on(i,2), traffic{sta}.on(i,2), traffic{sta}.on(i,1)], ...
             [sta-0.35, sta-0.35, sta+0.35, sta+0.35], ...
             [0.6 0.9 0.6], 'EdgeColor', 'none');
    end
    
    % OFF 구간 (회색)
    for i = 1:size(traffic{sta}.off, 1)
        fill([traffic{sta}.off(i,1), traffic{sta}.off(i,2), traffic{sta}.off(i,2), traffic{sta}.off(i,1)], ...
             [sta-0.35, sta-0.35, sta+0.35, sta+0.35], ...
             [0.85 0.85 0.85], 'EdgeColor', 'none');
    end
    
    % 패킷 도착 (빨간 선)
    if ~isempty(traffic{sta}.pkts)
        for p = 1:length(traffic{sta}.pkts)
            plot([traffic{sta}.pkts(p), traffic{sta}.pkts(p)], [sta-0.3, sta+0.3], 'r-', 'LineWidth', 1.5);
        end
    end
end

xlabel('시간 (초)');
ylabel('STA');
title('ON/OFF 구간 및 패킷 도착 시점');
yticks(1:num_stas);
xlim([0, sim_time]);
ylim([0.5, num_stas+0.5]);
grid on;

% 범례
h1 = fill(nan, nan, [0.6 0.9 0.6]);
h2 = fill(nan, nan, [0.85 0.85 0.85]);
h3 = plot(nan, nan, 'r-', 'LineWidth', 1.5);
legend([h1,h2,h3], {'ON 구간', 'OFF 구간', '패킷 도착'}, 'Location', 'northeast');

% 하단: 확대 (처음 100ms)
subplot(2,1,2);
hold on;

zoom_end = 0.1;  % 100ms

for sta = 1:num_stas
    % ON 구간
    for i = 1:size(traffic{sta}.on, 1)
        if traffic{sta}.on(i,1) < zoom_end
            t1 = traffic{sta}.on(i,1);
            t2 = min(traffic{sta}.on(i,2), zoom_end);
            fill([t1, t2, t2, t1], [sta-0.35, sta-0.35, sta+0.35, sta+0.35], ...
                 [0.6 0.9 0.6], 'EdgeColor', 'none');
        end
    end
    
    % OFF 구간
    for i = 1:size(traffic{sta}.off, 1)
        if traffic{sta}.off(i,1) < zoom_end
            t1 = traffic{sta}.off(i,1);
            t2 = min(traffic{sta}.off(i,2), zoom_end);
            fill([t1, t2, t2, t1], [sta-0.35, sta-0.35, sta+0.35, sta+0.35], ...
                 [0.85 0.85 0.85], 'EdgeColor', 'none');
        end
    end
    
    % 패킷
    pkts_in_range = traffic{sta}.pkts(traffic{sta}.pkts < zoom_end);
    for p = 1:length(pkts_in_range)
        plot([pkts_in_range(p), pkts_in_range(p)], [sta-0.3, sta+0.3], 'r-', 'LineWidth', 2);
    end
end

xlabel('시간 (초)');
ylabel('STA');
title('확대: 처음 100ms');
yticks(1:num_stas);
xlim([0, zoom_end]);
ylim([0.5, num_stas+0.5]);
grid on;

sgtitle(sprintf('Pareto ON/OFF 트래픽 (λ=%d, μ_{on}=%.0fms, ρ=%.1f)', lambda, mu_on*1000, rho));

%% OFF 구간 내 패킷 검증
fprintf('OFF 구간 내 패킷 검증\n');
fprintf('═══════════════════════════════════════\n');

errors = 0;
for sta = 1:num_stas
    for p = 1:length(traffic{sta}.pkts)
        pkt_time = traffic{sta}.pkts(p);
        
        in_off = false;
        for i = 1:size(traffic{sta}.off, 1)
            if pkt_time >= traffic{sta}.off(i,1) && pkt_time < traffic{sta}.off(i,2)
                in_off = true;
                fprintf('❌ STA%d: 패킷 %.4fs가 OFF [%.4f, %.4f]에 있음!\n', ...
                    sta, pkt_time, traffic{sta}.off(i,1), traffic{sta}.off(i,2));
                errors = errors + 1;
                break;
            end
        end
    end
end

if errors == 0
    fprintf('✅ 모든 패킷이 ON 구간에서만 생성됨!\n');
else
    fprintf('\n⚠️ %d개 패킷이 OFF 구간에서 발견됨\n', errors);
end

%% 통계
fprintf('\n통계\n');
fprintf('═══════════════════════════════════════\n');
for sta = 1:num_stas
    n_pkts = length(traffic{sta}.pkts);
    on_time = sum(traffic{sta}.on(:,2) - traffic{sta}.on(:,1));
    fprintf('STA%d: %d 패킷, ON %.1f%% (%.0fms)\n', sta, n_pkts, on_time/sim_time*100, on_time*1000);
end

fprintf('\n완료!\n');