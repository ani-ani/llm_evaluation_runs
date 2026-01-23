module gon_probability_generic #(
    parameter MAX_STATES = 16,
    parameter STATE_BITS = 4,
    parameter ITERATIONS = 256
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p,
    input wire [3:0] num_states,
    input wire [3:0] next_H [0:MAX_STATES-1],
    input wire [3:0] next_T [0:MAX_STATES-1],
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] ONE = 32'h00010000;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] ITERATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [31:0] p_inv;
    reg [31:0] state_val [0:MAX_STATES-1];
    reg [31:0] new_val [0:MAX_STATES-1];
    reg [STATE_BITS-1:0] idx;
    reg [7:0] iter;
    reg [7:0] sub_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            p_inv <= 32'd0;
            iter <= 8'd0;
            idx <= 0;
            sub_idx <= 8'd0;
            for (integer i = 0; i < MAX_STATES; i = i + 1) begin
                state_val[i] <= 32'd0;
                new_val[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        sub_idx <= 8'd0;
                        p_inv <= ONE - p;
                    end
                end

                INIT: begin
                    if (sub_idx < MAX_STATES) begin
                        state_val[sub_idx] <= 32'd0;
                        new_val[sub_idx] <= 32'd0;
                        sub_idx <= sub_idx + 8'd1;
                    end else begin
                        iter <= 8'd0;
                        idx <= 0;
                        state <= ITERATE;
                    end
                end

                ITERATE: begin
                    if (iter < ITERATIONS) begin
                        if (idx < num_states) begin
                            reg [31:0] h_val;
                            reg [31:0] t_val;
                            reg [63:0] h_mult;
                            reg [63:0] t_mult;

                            // Get value for H
                            case (next_H[idx])
                                4'd8:  h_val = ONE;
                                4'd9:  h_val = 32'd0;
                                4'd10: h_val = 32'd0;
                                default: h_val = state_val[next_H[idx]];
                            endcase

                            // Get value for T
                            case (next_T[idx])
                                4'd8:  t_val = ONE;
                                4'd9:  t_val = 32'd0;
                                4'd10: t_val = 32'd0;
                                default: t_val = state_val[next_T[idx]];
                            endcase

                            // Compute p * h_val + (1-p) * t_val
                            h_mult = p * h_val;
                            t_mult = p_inv * t_val;
                            new_val[idx] <= h_mult[47:16] + t_mult[47:16];
                            idx <= idx + 1;
                        end else begin
                            // Update all states
                            for (integer i = 0; i < MAX_STATES; i = i + 1) begin
                                state_val[i] <= new_val[i];
                            end
                            idx <= 0;
                            iter <= iter + 8'd1;
                        end
                    end else begin
                        result <= state_val[0];
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule