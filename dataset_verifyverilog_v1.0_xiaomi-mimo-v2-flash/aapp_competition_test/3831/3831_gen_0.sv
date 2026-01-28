module MayorLawnDemolition (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [127:0] s_arr,
    input wire [127:0] g_arr,
    output reg [15:0] result,
    output reg [127:0] s_prime_arr,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] FORWARD  = 3'd1;
    localparam [2:0] BACKWARD = 3'd2;
    localparam [2:0] COMPUTE  = 3'd3;
    localparam [2:0] DONE     = 3'd4;
    localparam [2:0] IMPOSSIBLE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] idx;
    reg [3:0] count;
    reg [7:0] L [0:15];
    reg [7:0] R [0:15];
    reg [7:0] s [0:15];
    reg [7:0] g [0:15];
    reg [15:0] sum;
    reg [15:0] temp_sum;
    reg impossible_flag;
    reg [15:0] result_reg;
    reg [127:0] s_prime_reg;
    integer i;

    // Combinational logic for finding max of two 8-bit values
    wire [7:0] max_val1;
    wire [7:0] max_val2;
    wire [7:0] min_val1;
    wire [7:0] min_val2;

    assign max_val1 = (L[idx] > L[idx-1]) ? L[idx] : L[idx-1];
    assign max_val2 = (L[idx] > (L[idx-1] - 8'd1)) ? L[idx] : (L[idx-1] - 8'd1);
    assign min_val1 = (R[idx] < R[idx-1]) ? R[idx] : R[idx-1];
    assign min_val2 = (R[idx] < (R[idx-1] + 8'd1)) ? R[idx] : (R[idx-1] + 8'd1);

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            s_prime_arr <= 128'd0;
            // Initialize all registers
            idx <= 4'd0;
            count <= 4'd0;
            sum <= 16'd0;
            temp_sum <= 16'd0;
            impossible_flag <= 1'b0;
            result_reg <= 16'd0;
            s_prime_reg <= 128'd0;
            for (i = 0; i < 16; i = i + 1) begin
                L[i] <= 8'd0;
                R[i] <= 8'd0;
                s[i] <= 8'd0;
                g[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input data
                        for (i = 0; i < 16; i = i + 1) begin
                            s[i] <= s_arr[i*8 +: 8];
                            g[i] <= g_arr[i*8 +: 8];
                            L[i] <= s_arr[i*8 +: 8];
                            R[i] <= s_arr[i*8 +: 8] + g_arr[i*8 +: 8];
                        end
                        idx <= 4'd1;
                        count <= n;
                        impossible_flag <= 1'b0;
                        state <= FORWARD;
                    end
                end

                FORWARD: begin
                    if (idx < count) begin
                        // Propagate constraints forward
                        L[idx] <= (L[idx] > (L[idx-1] - 8'd1)) ? L[idx] : (L[idx-1] - 8'd1);
                        R[idx] <= (R[idx] < (R[idx-1] + 8'd1)) ? R[idx] : (R[idx-1] + 8'd1);
                        
                        if (L[idx] > (R[idx-1] + 8'd1)) begin
                            // L[idx] > R[idx-1] + 1, but need to check after update
                            // This is checked in combinational logic for next state
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        // Check for impossibility in forward pass
                        idx <= (count > 4'd1) ? (count - 4'd2) : 4'd0;
                        if (count > 4'd1) begin
                            // Check all L[i] <= R[i] in forward pass
                            state <= BACKWARD;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                    // Check impossibility in forward pass
                    if (idx > 4'd0 && L[idx] > R[idx]) begin
                        impossible_flag <= 1'b1;
                    end
                end

                BACKWARD: begin
                    if (idx > 0) begin
                        // Propagate constraints backward
                        L[idx-1] <= (L[idx-1] > (L[idx] - 8'd1)) ? L[idx-1] : (L[idx] - 8'd1);
                        R[idx-1] <= (R[idx-1] < (R[idx] + 8'd1)) ? R[idx-1] : (R[idx] + 8'd1);
                        idx <= idx - 4'd1;
                    end else begin
                        state <= COMPUTE;
                    end
                    // Check for impossibility in backward pass
                    if (L[idx] > R[idx]) begin
                        impossible_flag <= 1'b1;
                    end
                end

                COMPUTE: begin
                    if (impossible_flag) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        // Choose s'[i] = R[i] for maximal demolition
                        // Accumulate sum
                        temp_sum <= 16'd0;
                        idx <= 4'd0;
                        sum <= 16'd0;
                    end
                end

                IMPOSSIBLE: begin
                    result_reg <= 16'hFFFF;
                    s_prime_reg <= 128'd0;
                    state <= DONE;
                end

                DONE: begin
                    result <= result_reg;
                    s_prime_arr <= s_prime_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Post-COMPUTE processing (cannot be in same cycle as COMPUTE state transition)
            if (state == COMPUTE && !impossible_flag) begin
                if (idx < count) begin
                    // Compute s'[i] = R[i]
                    s_prime_reg[idx*8 +: 8] <= R[idx];
                    // Add (R[i] - s[i]) to sum
                    sum <= sum + (R[idx] - s[idx]);
                    idx <= idx + 4'd1;
                end else if (idx == count) begin
                    result_reg <= sum;
                    state <= DONE;
                end
            end
        end
    end

endmodule