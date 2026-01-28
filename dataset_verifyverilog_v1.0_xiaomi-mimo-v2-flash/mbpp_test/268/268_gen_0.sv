module star_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] CALC1  = 3'd1;
    localparam [2:0] CALC2  = 3'd2;
    localparam [2:0] CALC3  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [15:0] temp_result;
    reg [15:0] temp_n_minus_1;
    reg [15:0] temp_6n;
    
    // Combinational signals for calculations
    wire [15:0] n_minus_1;
    wire [15:0] six_n;
    wire [31:0] mult_temp;
    wire [15:0] mult_result;
    wire [15:0] final_result;
    
    // Calculate n-1 (extend to 16 bits)
    assign n_minus_1 = {11'd0, n} - 16'd1;
    
    // Calculate 6*n (extend to 16 bits)
    assign six_n = {11'd0, n} * 16'd6;
    
    // Multiply: 6*n * (n-1)
    assign mult_temp = temp_6n * temp_n_minus_1;
    assign mult_result = mult_temp[15:0];  // Result fits in 16 bits
    
    // Final addition
    assign final_result = mult_result + 16'd1;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp_result <= 16'd0;
            temp_n_minus_1 <= 16'd0;
            temp_6n <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC1;
                    end
                end
                
                CALC1: begin
                    temp_n_minus_1 <= n_minus_1;
                    temp_6n <= six_n;
                    state <= CALC2;
                end
                
                CALC2: begin
                    temp_result <= mult_result;
                    state <= CALC3;
                end
                
                CALC3: begin
                    result <= final_result;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule