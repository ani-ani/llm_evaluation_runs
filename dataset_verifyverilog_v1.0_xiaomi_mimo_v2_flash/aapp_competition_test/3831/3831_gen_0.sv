module street_widening(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] s_in [0:15],
    input [15:0] g_in [0:15],
    output reg [31:0] total_removed,
    output reg [15:0] s_out [0:15],
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FORWARD    = 3'd1;
    localparam [2:0] BACKWARD   = 3'd2;
    localparam [2:0] VALIDATE   = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] idx;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd30;
    
    // Intermediate bounds storage
    reg [15:0] upper [0:15];
    reg [15:0] lower [0:15];
    reg [15:0] temp_s [0:15];
    reg [31:0] accum_removed;
    reg feasible;
    
    // Temporary variables for computation
    reg [15:0] sum_s;
    reg [15:0] sum_g;
    reg [31:0] temp_sum;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            total_removed <= 32'd0;
            idx <= 4'd0;
            cycle_count <= 4'd0;
            accum_removed <= 32'd0;
            feasible <= 1'b1;
            sum_s <= 16'd0;
            sum_g <= 16'd0;
            temp_sum <= 32'd0;
            for (i = 0; i < 16; i = i + 1) begin
                upper[i] <= 16'd0;
                lower[i] <= 16'd0;
                temp_s[i] <= 16'd0;
                s_out[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    total_removed <= 32'd0;
                    idx <= 4'd0;
                    cycle_count <= 4'd0;
                    accum_removed <= 32'd0;
                    feasible <= 1'b1;
                    sum_s <= 16'd0;
                    sum_g <= 16'd0;
                    temp_sum <= 32'd0;
                    if (start) begin
                        // Initialize bounds
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                upper[i] <= s_in[i] + g_in[i];
                                lower[i] <= s_in[i];
                                temp_s[i] <= s_in[i];
                            end else begin
                                upper[i] <= 16'd0;
                                lower[i] <= 16'd0;
                                temp_s[i] <= 16'd0;
                            end
                        end
                        state <= FORWARD;
                    end
                end
                
                FORWARD: begin
                    if (idx < n) begin
                        if (idx == 4'd0) begin
                            upper[idx] <= upper[idx];
                        end else begin
                            upper[idx] <= (upper[idx] < upper[idx-1]) ? upper[idx] : upper[idx-1];
                        end
                        idx <= idx + 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        idx <= n - 4'd1;
                        state <= BACKWARD;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        error <= 1'b1;
                        state <= FINISH;
                    end
                end
                
                BACKWARD: begin
                    if (idx >= 4'd1) begin
                        lower[idx-1] <= (lower[idx-1] > lower[idx]) ? lower[idx-1] : lower[idx];
                        idx <= idx - 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        idx <= 4'd0;
                        state <= VALIDATE;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        error <= 1'b1;
                        state <= FINISH;
                    end
                end
                
                VALIDATE: begin
                    if (idx < n) begin
                        // Check feasibility
                        if (lower[idx] > upper[idx]) begin
                            feasible <= 1'b0;
                        end
                        // Update temp_s to middle value
                        temp_s[idx] <= (lower[idx] + upper[idx]) >> 1;
                        idx <= idx + 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        if (feasible) begin
                            // Compute removed
                            accum_removed <= 32'd0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < n) begin
                                    accum_removed <= accum_removed + (s_in[i] - temp_s[i]);
                                end
                            end
                            // Copy results
                            for (i = 0; i < 16; i = i + 1) begin
                                s_out[i] <= temp_s[i];
                            end
                            total_removed <= accum_removed;
                        end
                        state <= FINISH;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        error <= 1'b1;
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