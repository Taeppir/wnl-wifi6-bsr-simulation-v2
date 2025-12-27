classdef MetricsCollector < handle
% METRICSCOLLECTOR: 성능 메트릭 수집기
%
% 시뮬레이션 중 다양한 성능 지표 수집 및 분석

    properties
        cfg                     % 설정
        
        %% TF별 누적 카운터
        total_tf_count          % 총 TF 횟수 (워밍업 제외)
        
        % UORA (RA-RU)
        ra_success_count        % RA-RU 성공 횟수
        ra_collision_count      % RA-RU 충돌 횟수
        ra_idle_count           % RA-RU 유휴 횟수
        
        % SA-RU
        sa_tx_count             % SA-RU 전송 횟수
        sa_idle_count           % SA-RU 유휴 횟수
        
        % BSR
        explicit_bsr_count      % Explicit BSR 횟수
        implicit_bsr_count      % Implicit BSR 횟수
        
        % 처리율
        total_tx_bytes          % 총 전송 바이트
        
        %% 패킷 레벨 메트릭
        delays                  % 지연 시간 배열 (슬롯 단위)
        delay_idx               % 현재 인덱스
        
        %% STA별 메트릭
        per_sta_success         % STA별 성공 횟수
        per_sta_collision       % STA별 충돌 횟수
        per_sta_bytes           % STA별 전송 바이트
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = MetricsCollector(cfg)
            obj.cfg = cfg;
            obj.reset();
        end
        
        %% ═══════════════════════════════════════════════════
        %  리셋
        %  ═══════════════════════════════════════════════════
        
        function reset(obj)
            obj.total_tf_count = 0;
            
            obj.ra_success_count = 0;
            obj.ra_collision_count = 0;
            obj.ra_idle_count = 0;
            
            obj.sa_tx_count = 0;
            obj.sa_idle_count = 0;
            
            obj.explicit_bsr_count = 0;
            obj.implicit_bsr_count = 0;
            
            obj.total_tx_bytes = 0;
            
            obj.delays = zeros(obj.cfg.max_packets, 1);
            obj.delay_idx = 0;
            
            obj.per_sta_success = zeros(obj.cfg.num_stas, 1);
            obj.per_sta_collision = zeros(obj.cfg.num_stas, 1);
            obj.per_sta_bytes = zeros(obj.cfg.num_stas, 1);
        end
        
        %% ═══════════════════════════════════════════════════
        %  TF별 수집
        %  ═══════════════════════════════════════════════════
        
        function collect(obj, slot, success, collided, idle, sa_assignments, stas, ~)
            obj.total_tf_count = obj.total_tf_count + 1;
            
            % RA-RU 통계
            ra_success = sum(strcmp({success.tx_type}, 'ra'));
            sa_success = sum(strcmp({success.tx_type}, 'sa'));
            
            obj.ra_success_count = obj.ra_success_count + ra_success;
            obj.ra_collision_count = obj.ra_collision_count + length(collided);
            obj.ra_idle_count = obj.ra_idle_count + idle.ra;
            
            % SA-RU 통계
            obj.sa_tx_count = obj.sa_tx_count + sa_success;
            obj.sa_idle_count = obj.sa_idle_count + idle.sa;
            
            % 성공한 전송 처리
            for i = 1:length(success)
                sta_idx = success(i).sta_idx;
                obj.per_sta_success(sta_idx) = obj.per_sta_success(sta_idx) + 1;
                obj.per_sta_bytes(sta_idx) = obj.per_sta_bytes(sta_idx) + obj.cfg.mpdu_size;
                obj.total_tx_bytes = obj.total_tx_bytes + obj.cfg.mpdu_size;
            end
            
            % 충돌한 전송 처리
            for i = 1:length(collided)
                sta_idx = collided(i);
                obj.per_sta_collision(sta_idx) = obj.per_sta_collision(sta_idx) + 1;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  BSR 기록
        %  ═══════════════════════════════════════════════════
        
        function record_explicit_bsr(obj)
            obj.explicit_bsr_count = obj.explicit_bsr_count + 1;
        end
        
        function record_implicit_bsr(obj)
            obj.implicit_bsr_count = obj.implicit_bsr_count + 1;
        end
        
        %% ═══════════════════════════════════════════════════
        %  지연 기록
        %  ═══════════════════════════════════════════════════
        
        function record_delay(obj, delay_slots)
            if obj.delay_idx < obj.cfg.max_packets
                obj.delay_idx = obj.delay_idx + 1;
                obj.delays(obj.delay_idx) = delay_slots;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  최종 결과 계산
        %  ═══════════════════════════════════════════════════
        
        function results = finalize(obj, stas)
            results = struct();
            
            %% 패킷 통계
            total_generated = sum([stas.num_packets]);
            total_completed = sum([stas.completed_packets]);
            
            results.packets.generated = total_generated;
            results.packets.completed = total_completed;
            if total_generated > 0
                results.packets.completion_rate = total_completed / total_generated;
            else
                results.packets.completion_rate = 0;
            end
            
            %% 지연 통계
            % STA에서 완료된 패킷의 지연 수집
            all_delays = [];
            for i = 1:length(stas)
                for j = 1:stas(i).num_packets
                    if stas(i).packets(j).completed
                        all_delays(end+1) = stas(i).packets(j).delay_slots;
                    end
                end
            end
            
            if ~isempty(all_delays)
                delay_ms = all_delays * obj.cfg.slot_duration * 1000;
                results.delay.mean_ms = mean(delay_ms);
                results.delay.p90_ms = prctile(delay_ms, 90);
                results.delay.p99_ms = prctile(delay_ms, 99);
                results.delay.max_ms = max(delay_ms);
                results.delay.std_ms = std(delay_ms);
            else
                results.delay.mean_ms = 0;
                results.delay.p90_ms = 0;
                results.delay.p99_ms = 0;
                results.delay.max_ms = 0;
                results.delay.std_ms = 0;
            end
            
            %% 처리율 통계
            % effective_time = TF 횟수 × TF 주기(슬롯) × 슬롯 길이
            effective_time = obj.total_tf_count * obj.cfg.frame_exchange_slots * obj.cfg.slot_duration;
            if effective_time > 0
                results.throughput.total_mbps = (obj.total_tx_bytes * 8) / effective_time / 1e6;
            else
                results.throughput.total_mbps = 0;
            end
            
            % 채널 이용률 (RA-RU 기준)
            % 전체 RA-RU 슬롯 = TF 횟수 × RA-RU 개수
            total_ra_ru_opportunities = obj.total_tf_count * obj.cfg.num_ru_ra;
            if total_ra_ru_opportunities > 0
                results.throughput.channel_utilization = obj.ra_success_count / total_ra_ru_opportunities;
            else
                results.throughput.channel_utilization = 0;
            end
            
            %% UORA 통계
            total_ra_attempts = obj.ra_success_count + obj.ra_collision_count;
            total_ra_outcomes = obj.ra_success_count + obj.ra_collision_count + obj.ra_idle_count;
            
            if total_ra_outcomes > 0
                results.uora.success_rate = obj.ra_success_count / total_ra_outcomes;
                results.uora.collision_rate = obj.ra_collision_count / total_ra_outcomes;
                results.uora.idle_rate = obj.ra_idle_count / total_ra_outcomes;
            else
                results.uora.success_rate = 0;
                results.uora.collision_rate = 0;
                results.uora.idle_rate = 0;
            end
            
            results.uora.total_attempts = total_ra_attempts;
            results.uora.total_success = obj.ra_success_count;
            results.uora.total_collision = obj.ra_collision_count;
            results.uora.total_idle = obj.ra_idle_count;
            
            %% BSR 통계
            results.bsr.explicit_count = obj.explicit_bsr_count;
            results.bsr.implicit_count = obj.implicit_bsr_count;
            
            total_bsr = obj.explicit_bsr_count + obj.implicit_bsr_count;
            if total_bsr > 0
                results.bsr.explicit_ratio = obj.explicit_bsr_count / total_bsr;
            else
                results.bsr.explicit_ratio = 0;
            end
            
            %% T_hold 통계 (Simulator에서 채워짐)
            results.thold.activations = 0;
            results.thold.hits = 0;
            results.thold.hit_rate = 0;
            results.thold.uora_avoided = 0;
            
            %% TF 통계
            results.tf.count = obj.total_tf_count;
            results.tf.period_slots = obj.cfg.frame_exchange_slots;
            results.tf.period_ms = obj.cfg.frame_exchange_slots * obj.cfg.slot_duration * 1000;
            
            %% 공정성 (Jain's Fairness Index)
            if obj.cfg.num_stas > 0
                throughputs = obj.per_sta_bytes * 8 / effective_time / 1e6;  % Mbps
                sum_th = sum(throughputs);
                sum_th_sq = sum(throughputs.^2);
                
                if sum_th_sq > 0
                    results.fairness.jain_index = sum_th^2 / (obj.cfg.num_stas * sum_th_sq);
                else
                    results.fairness.jain_index = 1;
                end
            else
                results.fairness.jain_index = 1;
            end
            
            %% Per-STA 통계
            if obj.cfg.collect_per_sta
                results.per_sta.success = obj.per_sta_success;
                results.per_sta.collision = obj.per_sta_collision;
                results.per_sta.bytes = obj.per_sta_bytes;
                results.per_sta.throughput_mbps = obj.per_sta_bytes * 8 / effective_time / 1e6;
            end
        end
    end
end
