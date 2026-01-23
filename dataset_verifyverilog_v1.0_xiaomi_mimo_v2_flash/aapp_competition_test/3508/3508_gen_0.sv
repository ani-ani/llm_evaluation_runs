module pillar_collapse (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] strength_0,
    input [15:0] strength_1,
    input [15:0] strength_2,
    input [15:0] strength_3,
    output reg [15:0] max_damage,
    output reg [3:0] best_pillar,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] SIM_LOOP   = 3'd2;
    localparam [2:0] SIM_DONE   = 3'd3;
    localparam [2:0] FINISHED   = 3'd4;

    reg [2:0] state;
    reg [3:0] current_i;
    reg [3:0] q_head;
    reg [3:0] q_tail;
    reg [3:0] i;
    reg [2:0] depth;
    
    // Internal registers
    reg [3:0] destroyed;
    reg [31:0] load [0:3];
    reg [3:0] queue [0:7];
    reg [3:0] damage_count;
    reg [15:0] current_max_damage;
    reg [3:0] current_best_pillar;
    reg [3:0] temp_pillar;
    reg [31:0] temp_load;
    
    // Strength array for indexed access
    reg [15:0] strength [0:3];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_damage <= 16'd0;
            best_pillar <= 4'd0;
            done <= 1'b0;
            current_i <= 4'd0;
            current_max_damage <= 16'd0;
            current_best_pillar <= 4'd0;
            q_head <= 4'd0;
            q_tail <= 4'd0;
            depth <= 3'd0;
            destroyed <= 4'b0000;
            damage_count <= 4'd0;
            temp_pillar <= 4'd0;
            temp_load <= 32'd0;
            for (i = 0; i < 4; i = i + 1) begin
                load[i] <= 32'd0;
                queue[i] <= 4'd0;
                strength[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        current_i <= 4'd0;
                        current_max_damage <= 16'd0;
                        current_best_pillar <= 4'd0;
                        // Load strengths
                        strength[0] <= strength_0;
                        strength[1] <= strength_1;
                        strength[2] <= strength_2;
                        strength[3] <= strength_3;
                    end
                end

                INIT: begin
                    // Initialize destroyed array
                    destroyed <= 4'b0000;
                    // Initialize loads
                    for (i = 0; i < 4; i = i + 1) begin
                        load[i] <= 32'd1000;
                    end
                    // Remove candidate pillar
                    destroyed[current_i] <= 1'b1;
                    // Redistribute load from candidate
                    if (current_i > 0) begin
                        load[current_i - 1] <= load[current_i - 1] + 32'd500;
                    end
                    if (current_i < n - 1) begin
                        load[current_i + 1] <= load[current_i + 1] + 32'd500;
                    end
                    // Initialize queue
                    q_head <= 4'd0;
                    q_tail <= 4'd0;
                    damage_count <= 4'd1;
                    depth <= 3'd0;
                    // Check immediate neighbors
                    if (current_i > 0 && !destroyed[current_i - 1] && load[current_i - 1] > strength[current_i - 1]) begin
                        queue[0] <= current_i - 1;
                        q_tail <= 4'd1;
                    end
                    if (current_i < n - 1 && !destroyed[current_i + 1] && load[current_i + 1] > strength[current_i + 1]) begin
                        if (current_i > 0) begin
                            queue[1] <= current_i + 1;
                            q_tail <= 4'd2;
                        end else begin
                            queue[0] <= current_i + 1;
                            q_tail <= 4'd1;
                        end
                    end
                    state <= SIM_LOOP;
                end

                SIM_LOOP: begin
                    if (q_head != q_tail && depth < 3'd6) begin
                        temp_pillar <= queue[q_head];
                        temp_load <= load[queue[q_head]];
                        if (!destroyed[queue[q_head]]) begin
                            destroyed[queue[q_head]] <= 1'b1;
                            damage_count <= damage_count + 4'd1;
                            // Redistribute load
                            if (queue[q_head] > 0 && !destroyed[queue[q_head] - 1]) begin
                                load[queue[q_head] - 1] <= load[queue[q_head] - 1] + (temp_load >> 1);
                            end
                            if (queue[q_head] < n - 1 && !destroyed[queue[q_head] + 1]) begin
                                load[queue[q_head] + 1] <= load[queue[q_head] + 1] + (temp_load >> 1);
                            end
                            // Check for new collapses
                            if (q_tail < 4'd8) begin
                                if (queue[q_head] > 0 && !destroyed[queue[q_head] - 1] && load[queue[q_head] - 1] > strength[queue[q_head] - 1]) begin
                                    queue[q_tail] <= queue[q_head] - 1;
                                    q_tail <= q_tail + 4'd1;
                                end
                                if (queue[q_head] < n - 1 && !destroyed[queue[q_head] + 1] && load[queue[q_head] + 1] > strength[queue[q_head] + 1]) begin
                                    queue[q_tail] <= queue[q_head] + 1;
                                    q_tail <= q_tail + 4'd1;
                                end
                            end
                        end
                        q_head <= q_head + 4'd1;
                        depth <= depth + 3'd1;
                        state <= SIM_LOOP;
                    end else begin
                        state <= SIM_DONE;
                    end
                end

                SIM_DONE: begin
                    if (damage_count > current_max_damage) begin
                        current_max_damage <= damage_count;
                        current_best_pillar <= current_i;
                    end
                    if (current_i < n - 1) begin
                        current_i <= current_i + 4'd1;
                        state <= INIT;
                    end else begin
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    max_damage <= current_max_damage;
                    best_pillar <= current_best_pillar;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule