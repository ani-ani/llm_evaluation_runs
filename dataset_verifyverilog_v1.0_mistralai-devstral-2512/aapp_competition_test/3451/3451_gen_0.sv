module ParenthesisUnbalance(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] k,
    input wire [15:0] str,
    input wire signed [7:0] cost [0:15],
    output reg signed [15:0] result,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Internal registers
    reg [3:0] current_n;
    reg [4:0] current_k;
    reg [15:0] current_str;
    reg signed [7:0] current_cost [0:15];
    
    reg [4:0] flip_index;
    reg signed [15:0] min_cost;
    reg [15:0] temp_str;
    reg signed [15:0] temp_balance;
    reg [15:0] balance_profile [0:15];
    reg signed [15:0] accumulated_cost;
    
    reg [3:0] i, j;
    reg signed [15:0] current_min;
    reg can_balance;
    reg found_impossible;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all internal registers
            current_n <= 4'd0;
            current_k <= 5'd0;
            current_str <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                current_cost[i] <= 8'd0;
            end
            
            flip_index <= 5'd0;
            min_cost <= 16'd0;
            temp_str <= 16'd0;
            temp_balance <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                balance_profile[i] <= 16'd0;
            end
            accumulated_cost <= 16'd0;
            current_min <= 16'd0;
            can_balance <= 1'b0;
            found_impossible <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Capture inputs
                        current_n <= n;
                        current_k <= k;
                        current_str <= str;
                        for (i = 0; i < 16; i = i + 1) begin
                            current_cost[i] <= cost[i];
                        end
                        
                        // Initialize computation
                        min_cost <= 16'd32767; // Start with max value
                        flip_index <= 5'd0;
                        found_impossible <= 1'b0;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all possible flips
                    if (flip_index >= current_n) begin
                        if (found_impossible) begin
                            result <= min_cost;
                            impossible <= 1'b1;
                        end else begin
                            result <= 16'd32768; // 0x8000 for impossible
                            impossible <= 1'b0;
                        end
                        next_state <= FINISH;
                    end else begin
                        // Create temporary string with current flip
                        temp_str <= current_str;
                        temp_str[flip_index] <= ~current_str[flip_index];
                        
                        // Compute balance profile for this flipped string
                        temp_balance <= 16'd0;
                        for (i = 0; i < current_n; i = i + 1) begin
                            if (temp_str[i] == 1'b0) begin
                                temp_balance <= temp_balance + 16'd1;
                            end else begin
                                temp_balance <= temp_balance - 16'd1;
                            end
                            balance_profile[i] <= temp_balance;
                        end
                        
                        // Check if this makes it impossible to balance
                        can_balance <= 1'b1;
                        
                        // Check total balance
                        if (temp_balance != 16'd0) begin
                            can_balance <= 1'b0;
                        end
                        
                        // Check if balance ever goes negative
                        if (can_balance) begin
                            for (i = 0; i < current_n; i = i + 1) begin
                                if (balance_profile[i] < 16'd0) begin
                                    can_balance <= 1'b0;
                                    break;
                                end
                            end
                        end
                        
                        // If this flip makes it impossible, track cost
                        if (!can_balance) begin
                            found_impossible <= 1'b1;
                            accumulated_cost <= current_cost[flip_index];
                            
                            // Check if this is the minimum cost
                            if (accumulated_cost < min_cost) begin
                                min_cost <= accumulated_cost;
                            end
                        end
                        
                        flip_index <= flip_index + 5'd1;
                        next_state <= COMPUTE;
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
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = IDLE;
            COMPUTE: next_state = COMPUTE;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule