module count_even_odd_pairs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COUNT      = 3'd1;
    localparam [2:0] COMPUTE_E  = 3'd2;
    localparam [2:0] COMPUTE_O  = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] count_even, count_odd;
    reg [3:0] index;
    reg [15:0] temp_even, temp_odd;
    reg [15:0] accumulated_result;

    // Flop for inputs
    reg [7:0] arr_reg [0:15];
    reg [3:0] len_reg;
    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COUNT;
                else next_state = IDLE;
            end
            COUNT: begin
                if (index >= len_reg) next_state = COMPUTE_E;
                else next_state = COUNT;
            end
            COMPUTE_E: next_state = COMPUTE_O;
            COMPUTE_O: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            count_even <= 4'd0;
            count_odd <= 4'd0;
            index <= 4'd0;
            temp_even <= 16'd0;
            temp_odd <= 16'd0;
            accumulated_result <= 16'd0;
            len_reg <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                arr_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        // Capture inputs
                        len_reg <= len;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < len) arr_reg[i] <= arr[i];
                            else arr_reg[i] <= 8'd0;
                        end
                        // Initialize counters
                        count_even <= 4'd0;
                        count_odd <= 4'd0;
                        index <= 4'd0;
                        accumulated_result <= 16'd0;
                    end
                end
                
                COUNT: begin
                    if (index < len_reg) begin
                        // Count even/odd based on LSB
                        if (arr_reg[index][0] == 1'b0) begin
                            count_even <= count_even + 4'd1;
                        end else begin
                            count_odd <= count_odd + 4'd1;
                        end
                        index <= index + 4'd1;
                    end
                end
                
                COMPUTE_E: begin
                    // Compute E*(E-1)/2 using arithmetic shift
                    // E*(E-1) fits in 16 bits for E <= 16
                    temp_even <= ((count_even * (count_even - 4'd1)) >> 1);
                end
                
                COMPUTE_O: begin
                    // Compute O*(O-1)/2 using arithmetic shift
                    temp_odd <= ((count_odd * (count_odd - 4'd1)) >> 1);
                    // Accumulate final result
                    accumulated_result <= ((count_even * (count_even - 4'd1)) >> 1) + 
                                         ((count_odd * (count_odd - 4'd1)) >> 1);
                end
                
                FINISH: begin
                    result <= accumulated_result;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule