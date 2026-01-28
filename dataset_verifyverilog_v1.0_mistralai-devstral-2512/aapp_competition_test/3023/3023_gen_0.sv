module candle_cut_checker(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [3:0] m,
    input [15:0] candle_x,
    input [15:0] candle_y,
    input [31:0] cut_a,
    input [31:0] cut_b,
    input [31:0] cut_c,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Candle and cut storage
    reg [3:0] candle_x_reg [0:15];
    reg [3:0] candle_y_reg [0:15];
    reg signed [7:0] cut_a_reg [0:7];
    reg signed [7:0] cut_b_reg [0:7];
    reg signed [7:0] cut_c_reg [0:7];

    // Signature storage
    reg [7:0] signature [0:15];
    reg [7:0] current_signature;
    reg [4:0] candle_index;
    reg [3:0] cut_index;
    reg [7:0] unique_count;
    reg [7:0] collision_detected;

    // Temporary computation registers
    reg signed [15:0] sum;
    reg [7:0] signature_temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 1'b0;
            candle_index <= 5'd0;
            cut_index <= 4'd0;
            unique_count <= 8'd0;
            collision_detected <= 8'd0;
            current_signature <= 8'd0;
            signature_temp <= 8'd0;

            // Initialize storage
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                candle_x_reg[i] <= 4'd0;
                candle_y_reg[i] <= 4'd0;
                signature[i] <= 8'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                cut_a_reg[i] <= 8'd0;
                cut_b_reg[i] <= 8'd0;
                cut_c_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load candles
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        candle_x_reg[i] <= candle_x[(i*4)+:4];
                        candle_y_reg[i] <= candle_y[(i*4)+:4];
                    end

                    // Load cuts
                    for (i = 0; i < 8; i = i + 1) begin
                        cut_a_reg[i] <= cut_a[(i*8)+:8];
                        cut_b_reg[i] <= cut_b[(i*8)+:8];
                        cut_c_reg[i] <= cut_c[(i*8)+:8];
                    end

                    next_state <= COMPUTE;
                    candle_index <= 5'd0;
                    cut_index <= 4'd0;
                    current_signature <= 8'd0;
                end

                COMPUTE: begin
                    if (candle_index < n) begin
                        if (cut_index < m) begin
                            // Compute sum for current cut
                            sum <= cut_a_reg[cut_index] * candle_x_reg[candle_index] +
                                  cut_b_reg[cut_index] * candle_y_reg[candle_index] +
                                  cut_c_reg[cut_index];

                            // Determine sign bit
                            if (sum > 16'd0) begin
                                signature_temp[cut_index] <= 1'b1;
                            end else begin
                                signature_temp[cut_index] <= 1'b0;
                            end

                            cut_index <= cut_index + 1'b1;
                        end else begin
                            // Store signature for this candle
                            signature[candle_index] <= signature_temp;
                            cut_index <= 4'd0;
                            candle_index <= candle_index + 1'b1;
                            signature_temp <= 8'd0;
                        end
                    end else begin
                        next_state <= CHECK;
                        unique_count <= 8'd0;
                        collision_detected <= 8'd0;
                        candle_index <= 5'd0;
                    end
                end

                CHECK: begin
                    if (candle_index < n) begin
                        // Check if this signature is unique
                        reg [7:0] temp_sig;
                        reg collision;
                        integer i;

                        temp_sig <= signature[candle_index];
                        collision <= 1'b0;

                        for (i = 0; i < candle_index; i = i + 1) begin
                            if (signature[i] == temp_sig) begin
                                collision <= 1'b1;
                            end
                        end

                        if (!collision) begin
                            unique_count <= unique_count + 1'b1;
                        end

                        candle_index <= candle_index + 1'b1;
                    end else begin
                        // Check if all signatures are unique
                        if (unique_count == n) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule