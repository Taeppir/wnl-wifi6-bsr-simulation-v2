classdef TrafficGenerator < handle
% TRAFFICGENERATOR: 트래픽 생성기
%
% 다양한 트래픽 모델 지원: Saturated, Poisson, Pareto On/Off

    properties
        model           % 트래픽 모델
        cfg             % 설정
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = TrafficGenerator(cfg)
            obj.model = cfg.traffic_model;
            obj.cfg = cfg;
        end
        
        %% ═══════════════════════════════════════════════════
        %  트래픽 생성
        %  ═══════════════════════════════════════════════════
        
        function stas = generate(obj, stas)
            switch obj.model
                case 'saturated'
                    stas = obj.generate_saturated(stas);
                case 'poisson'
                    stas = obj.generate_poisson(stas);
                case 'pareto_onoff'
                    stas = obj.generate_pareto_onoff(stas);
                otherwise
                    error('알 수 없는 트래픽 모델: %s', obj.model);
            end
        end
    end
    
    methods (Access = private)
        %% ═══════════════════════════════════════════════════
        %  Saturated 트래픽 (항상 데이터 있음)
        %  ═══════════════════════════════════════════════════
        
        function stas = generate_saturated(obj, stas)
            % 매 슬롯마다 패킷이 있다고 가정
            % 실제로는 큐가 항상 가득 찬 상태 유지
            
            for i = 1:length(stas)
                % 충분히 많은 패킷 생성
                num_pkts = obj.cfg.total_slots;
                
                stas(i).packets = struct(...
                    'idx', num2cell(1:num_pkts)', ...
                    'size', num2cell(obj.cfg.mpdu_size * ones(num_pkts, 1)), ...
                    'arrival_time', num2cell(zeros(num_pkts, 1)), ...
                    'arrival_slot', num2cell(zeros(num_pkts, 1)), ...
                    'enqueue_slot', num2cell(zeros(num_pkts, 1)), ...
                    'completion_slot', num2cell(zeros(num_pkts, 1)), ...
                    'completed', num2cell(false(num_pkts, 1)), ...
                    'delay_slots', num2cell(zeros(num_pkts, 1)) ...
                );
                
                stas(i).num_packets = num_pkts;
                stas(i).next_packet_idx = 1;
                
                % 초기 큐 설정 (항상 가득 참)
                stas(i).queue_size = obj.cfg.mpdu_size;
                stas(i).queue_packets = 1;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  Poisson 트래픽
        %  ═══════════════════════════════════════════════════
        
        function stas = generate_poisson(obj, stas)
            rate = obj.cfg.poisson_rate;  % 패킷/초
            sim_time = obj.cfg.simulation_time;
            pkt_size = obj.cfg.mpdu_size;
            
            % STA별 예상 패킷 수 (여유 있게 3배)
            expected_packets = ceil(rate * sim_time * 3);
            expected_packets = min(expected_packets, obj.cfg.max_packets);
            
            for i = 1:length(stas)
                current_time = 0;
                
                % 미리 할당
                packets = repmat(struct('idx', 0, 'size', 0, 'arrival_time', 0, ...
                    'arrival_slot', 0, 'enqueue_slot', 0, 'completion_slot', 0, ...
                    'completed', false, 'delay_slots', 0), expected_packets, 1);
                idx = 0;
                
                while current_time < sim_time && idx < expected_packets
                    inter_arrival = -log(rand()) / rate;
                    current_time = current_time + inter_arrival;
                    
                    if current_time < sim_time
                        idx = idx + 1;
                        packets(idx).idx = idx;
                        packets(idx).size = pkt_size;
                        packets(idx).arrival_time = current_time;
                    end
                end
                
                % 실제 사용한 패킷만 저장
                stas(i).packets = packets(1:idx);
                stas(i).num_packets = idx;
                stas(i).next_packet_idx = 1;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  Pareto On/Off 트래픽
        %  ═══════════════════════════════════════════════════
        
        function stas = generate_pareto_onoff(obj, stas)
            alpha = obj.cfg.pareto_alpha;
            mu_on = obj.cfg.mu_on;
            mu_off = obj.cfg.mu_off;
            lambda = obj.cfg.lambda;
            sim_time = obj.cfg.simulation_time;
            pkt_size = obj.cfg.mpdu_size;
            
            % Pareto 분포 최소값 계산
            k_on = mu_on * (alpha - 1) / alpha;
            k_off = mu_off * (alpha - 1) / alpha;
            
            % STA별 예상 패킷 수 (여유 있게 3배)
            rho = mu_on / (mu_on + mu_off);
            expected_packets = ceil(rho * lambda * sim_time * 3);
            expected_packets = min(expected_packets, obj.cfg.max_packets);
            
            for i = 1:length(stas)
                current_time = 0;
                
                % 미리 할당
                packets = repmat(struct('idx', 0, 'size', 0, 'arrival_time', 0, ...
                    'arrival_slot', 0, 'enqueue_slot', 0, 'completion_slot', 0, ...
                    'completed', false, 'delay_slots', 0), expected_packets, 1);
                idx = 0;
                is_on = false;  % Off 상태로 시작
                
                while current_time < sim_time && idx < expected_packets
                    if is_on
                        % On Period
                        on_duration = obj.sample_pareto(k_on, alpha);
                        on_end = current_time + on_duration;
                        
                        % On 기간 동안 Poisson 도착
                        while current_time < on_end && current_time < sim_time && idx < expected_packets
                            inter_arrival = -log(rand()) / lambda;
                            arrival_time = current_time + inter_arrival;
                            
                            if arrival_time < on_end && arrival_time < sim_time
                                idx = idx + 1;
                                packets(idx).idx = idx;
                                packets(idx).size = pkt_size;
                                packets(idx).arrival_time = arrival_time;
                                
                                current_time = arrival_time;
                            else
                                break;
                            end
                        end
                        
                        current_time = on_end;
                        is_on = false;
                    else
                        % Off Period
                        off_duration = obj.sample_pareto(k_off, alpha);
                        current_time = current_time + off_duration;
                        is_on = true;
                    end
                end
                
                % 실제 사용한 패킷만 저장
                stas(i).packets = packets(1:idx);
                stas(i).num_packets = idx;
                stas(i).next_packet_idx = 1;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  Pareto 샘플링
        %  ═══════════════════════════════════════════════════
        
        function x = sample_pareto(~, k, alpha)
            u = rand();
            x = k / (u^(1/alpha));
        end
    end
end