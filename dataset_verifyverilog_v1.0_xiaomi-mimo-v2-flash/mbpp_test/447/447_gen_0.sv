module cube_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [23:0] result,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] CALC1    = 3'd2;
    localparam [2:0] CALC2    = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] DONE     = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [2:0] index;           // Current element index (0-7)
    reg [7:0] current_elem;    // Current element being processed
    reg [15:0] intermediate;   // Intermediate result (x*x)
    reg [3:0] max_index;       // Maximum index (len-1)
    reg [15:0] mult_a;         // Multiplier input A
    reg [15:0] mult_b;         // Multiplier input B
    wire [31:0] mult_result;   // Multiplier output (32-bit)
    
    // Multiplier instantiation (combinational for speed)
    // Using 16-bit inputs to handle x*x (max 255*255 = 65025 fits in 16 bits)
    assign mult_result = mult_a * mult_b;
    
    // Control signals
    reg calc_in_progress;
    reg [1:0] calc_step;       // 0: x*x, 1: (x*x)*x, 2: done
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            current_elem <= 8'd0;
            intermediate <= 16'd0;
            max_index <= 4'd0;
            mult_a <= 16'd0;
            mult_b <= 16'd0;
            calc_in_progress <= 1'b0;
            calc_step <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    index <= 3'd0;
                    calc_in_progress <= 1'b0;
                    calc_step <= 2'd0;
                    if (start) begin
                        max_index <= (len > 4'd8) ? 4'd7 : (len - 4'd1);
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load current element
                    current_elem <= arr[index];
                    calc_step <= 2'd0;
                    calc_in_progress <= 1'b1;
                    // First multiplication: x * x
                    mult_a <= {8'd0, arr[index]};
                    mult_b <= {8'd0, arr[index]};
                    state <= CALC1;
                end
                
                CALC1: begin
                    // Capture x*x result
                    intermediate <= mult_result[15:0];
                    calc_step <= 2'd1;
                    // Second multiplication: (x*x) * x
                    mult_a <= mult_result[15:0];
                    mult_b <= {8'd0, current_elem};
                    state <= CALC2;
                end
                
                CALC2: begin
                    // Capture final cube result
                    result <= mult_result[23:0];
                    calc_step <= 2'd2;
                    calc_in_progress <= 1'b0;
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    result_valid <= 1'b1;
                    if (index < max_index) begin
                        // More elements to process
                        index <= index + 3'd1;
                        state <= LOAD;
                    end else begin
                        // Last element processed
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule