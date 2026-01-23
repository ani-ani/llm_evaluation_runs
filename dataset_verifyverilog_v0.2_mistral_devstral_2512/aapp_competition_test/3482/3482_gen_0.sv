module transit_card_optimizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] l,
    input [11:0] price [0:3],
    input [19:0] duration [0:2],
    input [4:0] t,
    input [2:0] n,
    input [4:0] trip_start [0:3],
    input [4:0] trip_end [0:3],
    output reg [23:0] min_cost,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        BUILD_MASK,
        GENERATE_PARTITIONS,
        EVALUATE,
        DONE
    } state_t;

    state_t state;
    reg [15:0] timeline_mask;
    reg [4:0] current_day;
    reg [3:0] partition_idx;
    reg [23:0] current_cost;
    reg [23:0] best_cost;
    reg [3:0] interval_start;
    reg [3:0] interval_end;
    reg [3:0] price_level;
    reg [19:0] cumulative_duration;
    reg [3:0] partition_count;
    reg [3:0] partition_start [0:7];
    reg [3:0] partition_end [0:7];
    reg [3:0] partition_level [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            timeline_mask <= 0;
            current_day <= 0;
            partition_idx <= 0;
            current_cost <= 0;
            best_cost <= 0;
            interval_start <= 0;
            interval_end <= 0;
            price_level <= 0;
            cumulative_duration <= 0;
            partition_count <= 0;
            min_cost <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= BUILD_MASK;
                        timeline_mask <= 0;
                        current_day <= 0;
                        best_cost <= '1;
                    end
                end
                BUILD_MASK: begin
                    if (current_day < t) begin
                        reg needs_coverage = 1'b1;
                        for (int i = 0; i < n; i++) begin
                            if (trip_start[i] <= current_day + 1 && current_day + 1 <= trip_end[i]) begin
                                needs_coverage = 1'b0;
                            end
                        end
                        timeline_mask[current_day] = needs_coverage;
                        current_day <= current_day + 1;
                    end else begin
                        state <= GENERATE_PARTITIONS;
                        partition_idx <= 0;
                        partition_count <= 0;
                    end
                end
                GENERATE_PARTITIONS: begin
                    if (partition_count < 8) begin
                        // Generate partitions (simplified for synthesis)
                        partition_start[partition_count] = partition_idx;
                        partition_end[partition_count] = partition_idx + 1;
                        partition_level[partition_count] = 0;
                        partition_count <= partition_count + 1;
                        partition_idx <= partition_idx + 1;
                    end else begin
                        state <= EVALUATE;
                        current_cost <= 0;
                        price_level <= 0;
                        cumulative_duration <= 0;
                    end
                end
                EVALUATE: begin
                    if (price_level < l) begin
                        reg [19:0] level_duration = duration[price_level];
                        reg [19:0] level_end = cumulative_duration + level_duration;
                        
                        for (int i = 0; i < partition_count; i++) begin
                            reg [4:0] start_day = partition_start[i];
                            reg [4:0] end_day = partition_end[i];
                            
                            if (start_day >= cumulative_duration && end_day <= level_end) begin
                                current_cost <= current_cost + (end_day - start_day + 1) * price[price_level];
                            end
                        end
                        
                        cumulative_duration <= cumulative_duration + level_duration;
                        price_level <= price_level + 1;
                    end else begin
                        if (current_cost < best_cost) begin
                            best_cost <= current_cost;
                        end
                        
                        // Move to next partition
                        if (partition_count < 8) begin
                            state <= EVALUATE;
                            current_cost <= 0;
                            price_level <= 0;
                            cumulative_duration <= 0;
                        end else begin
                            state <= DONE;
                            min_cost <= best_cost;
                            done <= 1'b1;
                        end
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule