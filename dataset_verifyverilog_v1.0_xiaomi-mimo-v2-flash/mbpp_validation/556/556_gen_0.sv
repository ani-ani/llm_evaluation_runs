module pair_xor_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_LOOP = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] INC_J     = 3'd3;
    localparam [2:0] INC_I     = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] i_counter;       // i from 0 to 7
    reg [3:0] j_counter;       // j from i+1 to 8 (needs extra bit for overflow)
    reg [15:0] result_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Compute XOR and check odd in combinational logic
    wire [7:0] xor_result;
    wire is_odd;
    assign xor_result = arr[i_counter] ^ arr[j_counter];
    assign is_odd = xor_result[0];  // Check LSB for oddness

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            result_reg <= 16'd0;
            i_counter <= 3'd0;
            j_counter <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    result_reg <= 16'd0;
                    i_counter <= 3'd0;
                    j_counter <= 4'd0;
                    if (start) begin
                        state <= INIT_LOOP;
                    end
                end

                INIT_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize j = i + 1
                    j_counter <= {1'b0, i_counter} + 4'd1;
                    if (i_counter < 3'd7) begin
                        state <= COMPUTE;
                    end else begin
                        state <= FINISH;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if XOR is odd
                    if (is_odd) begin
                        result_reg <= result_reg + 16'd1;
                    end
                    state <= INC_J;
                end

                INC_J: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Increment j
                    j_counter <= j_counter + 4'd1;
                    // Check if j reached 8 (end of array)
                    if (j_counter >= 4'd8) begin
                        state <= INC_I;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                INC_I: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Increment i
                    i_counter <= i_counter + 3'd1;
                    // Check if i reached 7 (last pair start)
                    if (i_counter >= 3'd7) begin
                        state <= FINISH;
                    end else begin
                        state <= INIT_LOOP;
                    end
                end

                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule