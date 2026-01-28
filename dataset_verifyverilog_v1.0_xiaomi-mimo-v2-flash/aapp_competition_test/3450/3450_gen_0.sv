module factorial_digits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [11:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] MULTIPLY   = 3'd2;
    localparam [2:0] DIVIDE     = 3'd3;
    localparam [2:0] EXTRACT    = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [63:0] fact;
    reg [3:0] counter;
    reg [3:0] target_n;
    reg dividing;
    reg [15:0] cycle_counter;
    
    // Overflow prevention for n=16 (requires 64 bits)
    localparam [7:0] MAX_CYCLES = 8'd150;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && (n >= 4'd1) && (n <= 4'd16)) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = MULTIPLY;
            end
            
            MULTIPLY: begin
                if (counter >= target_n) begin
                    next_state = DIVIDE;
                end
            end
            
            DIVIDE: begin
                if ((fact % 10 != 0) || (fact == 64'd0)) begin
                    next_state = EXTRACT;
                end
            end
            
            EXTRACT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fact <= 64'd0;
            counter <= 4'd0;
            target_n <= 4'd0;
            dividing <= 1'b0;
            result <= 12'd0;
            done <= 1'b0;
            cycle_counter <= 16'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 16'd0;
                    if (start && (n >= 4'd1) && (n <= 4'd16)) begin
                        target_n <= n;
                    end
                end
                
                LOAD: begin
                    fact <= 64'd1;
                    counter <= 4'd1;
                    cycle_counter <= cycle_counter + 16'd1;
                end
                
                MULTIPLY: begin
                    if (counter <= target_n) begin
                        fact <= fact * counter;
                        counter <= counter + 4'd1;
                    end
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    // Prevent infinite loop
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                DIVIDE: begin
                    if (fact[3:0] == 4'd0 && fact != 64'd0) begin
                        fact <= fact >> 4'd4; // Divide by 16 (2 trailing zeros)
                        dividing <= 1'b1;
                    end else if (fact[0] == 1'b0 && fact != 64'd0) begin
                        fact <= fact >> 1; // Divide by 2
                        dividing <= 1'b1;
                    end else begin
                        dividing <= 1'b0;
                    end
                    cycle_counter <= cycle_counter + 16'd1;
                    
                    // Safety: if fact becomes 0, go to finish
                    if (fact == 64'd0) begin
                        state <= FINISH;
                    end
                end
                
                EXTRACT: begin
                    // Get last 3 digits (fact % 1000)
                    // Using modulo operation
                    result <= fact[11:0]; // fact already small enough for n<=16
                    cycle_counter <= cycle_counter + 16'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule