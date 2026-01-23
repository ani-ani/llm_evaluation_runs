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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SIM_LOOP = 3'd2;
    localparam [2:0] SIM_DONE = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state;
    reg [3:0] current_i;
    reg [3:0] i;

    reg [3:0] destroyed;
    reg [31:0] load_0, load_1, load_2, load_3;
    reg [3:0] queue_0, queue_1, queue_2, queue_3;
    reg [2:0] q_head, q_tail;
    reg [3:0] damage_count;
    reg [15:0] current_max_damage;
    reg [3:0] current_best_pillar;

    wire [15:0] strength [0:3];
    assign strength[0] = strength_0;
    assign strength[1] = strength_1;
    assign strength[2] = strength_2;
    assign strength[3] = strength_3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_damage <= 16'd0;
            best_pillar <= 4'd0;
            done <= 1'b0;
            current_i <= 4'd0;
            current_max_damage <= 16'd0;
            current_best_pillar <= 4'd0;
            destroyed <= 4'd0;
            load_0 <= 32'd0;
            load_1 <= 32'd0;
            load_2 <= 32'd0;
            load_3 <= 32'd0;
            queue_0 <= 4'd0;
            queue_1 <= 4'd0;
            queue_2 <= 4'd0;
            queue_3 <= 4'd0;
            q_head <= 3'd0;
            q_tail <= 3'd0;
            damage_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        current_i <= 4'd0;
                        current_max_damage <= 16'd0;
                        current_best_pillar <= 4'd0;
                    end
                end

                INIT: begin
                    destroyed <= 4'd0;
                    load_0 <= 32'd1000;
                    load_1 <= 32'd1000;
                    load_2 <= 32'd1000;
                    load_3 <= 32'd1000;
                    destroyed[current_i] <= 1'b1;
                    if (current_i > 0) begin
                        load_0 <= load_0 + 32'd500;
                    end
                    if (current_i < n-1) begin
                        load_1 <= load_1 + 32'd500;
                    end
                    q_head <= 3'd0;
                    q_tail <= 3'd0;
                    damage_count <= 4'd1;
                    if (current_i > 0 && load_0 > strength[current_i-1]) begin
                        queue_0 <= current_i-1;
                        q_tail <= q_tail + 1;
                    end
                    if (current_i < n-1 && load_1 > strength[current_i+1]) begin
                        queue_1 <= current_i+1;
                        q_tail <= q_tail + 1;
                    end
                    state <= SIM_LOOP;
                end

                SIM_LOOP: begin
                    if (q_head != q_tail) begin
                        if (!destroyed[queue_0]) begin
                            destroyed[queue_0] <= 1'b1;
                            damage_count <= damage_count + 1;
                            if (queue_0 > 0 && !destroyed[queue_0-1]) begin
                                load_0 <= load_0 + (load_1 >> 1);
                            end
                            if (queue_0 < n-1 && !destroyed[queue_0+1]) begin
                                load_1 <= load_1 + (load_2 >> 1);
                            end
                            if (queue_0 > 0 && !destroyed[queue_0-1] && load_0 > strength[queue_0-1]) begin
                                queue_2 <= queue_0-1;
                                q_tail <= q_tail + 1;
                            end
                            if (queue_0 < n-1 && !destroyed[queue_0+1] && load_1 > strength[queue_0+1]) begin
                                queue_3 <= queue_0+1;
                                q_tail <= q_tail + 1;
                            end
                        end
                        q_head <= q_head + 1;
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
                    if (current_i < n-1) begin
                        current_i <= current_i + 1;
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