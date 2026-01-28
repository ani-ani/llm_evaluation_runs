module PermutationShiftOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [3:0] n,
    output reg [15:0] min_deviation,
    output reg [3:0] best_shift,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [3:0] shift_counter;
    reg [3:0] element_counter;
    reg [15:0] current_deviation;

    reg [3:0] perm [0:7];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_deviation <= 16'd0;
            best_shift <= 4'd0;
            shift_counter <= 4'd0;
            element_counter <= 4'd0;
            current_deviation <= 16'd0;
            for (i = 0; i < 8; i = i + 1) begin
                perm[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        shift_counter <= 4'd0;
                        element_counter <= 4'd0;
                        min_deviation <= 16'hFFFF;
                        best_shift <= 4'd0;
                    end
                end

                LOAD: begin
                    case (element_counter)
                        4'd0: perm[0] <= p_0;
                        4'd1: perm[1] <= p_1;
                        4'd2: perm[2] <= p_2;
                        4'd3: perm[3] <= p_3;
                        4'd4: perm[4] <= p_4;
                        4'd5: perm[5] <= p_5;
                        4'd6: perm[6] <= p_6;
                        4'd7: perm[7] <= p_7;
                    endcase

                    element_counter <= element_counter + 1'b1;
                    if (element_counter == n) begin
                        state <= COMPUTE;
                        element_counter <= 4'd0;
                        current_deviation <= 16'd0;
                    end
                end

                COMPUTE: begin
                    if (element_counter < n) begin
                        reg [3:0] perm_val = perm[element_counter];
                        reg [3:0] target_pos = (element_counter + shift_counter) % n;
                        reg [4:0] diff = perm_val - target_pos - 1'b1;
                        reg [4:0] abs_diff = diff[4] ? (~diff + 1'b1) : diff;
                        current_deviation <= current_deviation + abs_diff;
                        element_counter <= element_counter + 1'b1;
                    end else begin
                        if (current_deviation < min_deviation) begin
                            min_deviation <= current_deviation;
                            best_shift <= shift_counter;
                        end

                        shift_counter <= shift_counter + 1'b1;
                        element_counter <= 4'd0;
                        current_deviation <= 16'd0;

                        if (shift_counter == n) begin
                            state <= DONE;
                            done <= 1'b1;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule