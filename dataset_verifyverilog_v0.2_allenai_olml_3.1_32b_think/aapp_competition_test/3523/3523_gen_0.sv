module coin_change_max (
    input clk,
    input rst_n,
    input start,
    input [15:0] price,
    input [6:0] n1, n5, n10, n25,
    output reg [15:0] max_coins,
    output reg done,
    output reg impossible
);

// Internal state register
reg [2:0] state;

// Define states
localparam IDLE = 3'b000;
localparam INIT = 3'b001;
localparam COIN_1 = 3'b010;
localparam COIN_5 = 3'b011;
localparam COIN_10 = 3'b100;
localparam COIN_25 = 3'b101;
localparam VERIFY = 3'b110;
localparam DONE = 3'b111;

// Default next state
reg [2:0] next_state;

// Initialize DP table (commented for synthesis)
// reg [15:0] dp_table [0:1023];

// Registers for captured inputs
reg [15:0] captured_price;
reg [6:0] captured_n1, captured_n5, captured_n10, captured_n25;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        max_coins <= 16'b0;
        // Initialize captured inputs
        captured_price <= 16'b0;
        captured_n1 <= 7'b0;
        captured_n5 <= 7'b0;
        captured_n10 <= 7'b0;
        captured_n25 <= 7'b0;
        // DP initialization commented for synthesis
        // for (int i=0; i<1024; i++) dp_table[i] <= (i==0) ? 16'b0 : 16'bFFFF;
    end else begin
        // Capture inputs when starting
        if (state == IDLE && start) begin
            captured_price <= price;
            captured_n1 <= n1;
            captured_n5 <= n5;
            captured_n10 <= n10;
            captured_n25 <= n25;
        end

        state <= next_state;

        case (state)
            IDLE: 
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
                done <= 1'b0;
                impossible <= 1'b0;
                max_coins <= 16'b0;
                break;
            
            INIT: 
                next_state = COIN_1;
                done <= 1'b0;
                impossible <= 1'b0;
                max_coins <= 16'b0;
                break;
            
            COIN_1: 
                next_state = COIN_5;
                done <= 1'b0;
                impossible <= 1'b0;
                max_coins <= 16'b0;
                break;
            
            COIN_5:
                next_state = COIN_10;
                done <= 1'b0;
                impossible <= 1'b0;
                max_coins <= 16'b0;
                break;
            
            COIN_10:
                next_state = COIN_25;
                done <= 1'b0;
                impossible <= 1'b0;
                max_coins <= 16'b0;
                break;
            
            COIN_25:
                next_state = VERIFY;
                done <= 1'b0;
                impossible <= 1'b0;
                max_coins <= 16'b0;
                break;
            
            VERIFY:
                if (captured_price == 16'd0) begin
                    max_coins <= 16'b0;
                    impossible <= 1'b0;
                end else begin
                    impossible <= 1'b1;
                    max_coins <= 16'bFFFF;
                end
                next_state = DONE;
                done <= 1'b1;
                break;
            
            DONE:
                next_state = DONE;
                done <= 1'b1;
                // retain max_coins and impossible
                break;
            
            default: next_state = IDLE;
        endcase
    end
endmodule