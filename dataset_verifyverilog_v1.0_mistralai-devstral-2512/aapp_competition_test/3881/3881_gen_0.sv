module string_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] rule_in_idx,
    input wire [11:0] rule_in_2char,
    input wire [5:0] rule_in_dest,
    input wire rule_write,
    input wire [2:0] n,
    output reg [23:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Rule table: 36 entries, each with valid, first, second, dest
    reg [0:0] rule_valid [0:35];
    reg [5:0] rule_first [0:35];
    reg [5:0] rule_second [0:35];
    reg [5:0] rule_dest [0:35];

    // Current and next arrays for counts
    reg [23:0] current [0:5];
    reg [23:0] next [0:5];

    // Loop counters
    reg [5:0] i;
    reg [5:0] j;
    reg [5:0] k;
    reg [2:0] loop_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize rule table
            integer idx;
            for (idx = 0; idx < 36; idx = idx + 1) begin
                rule_valid[idx] <= 1'b0;
                rule_first[idx] <= 6'd0;
                rule_second[idx] <= 6'd0;
                rule_dest[idx] <= 6'd0;
            end
            
            // Initialize current array
            current[0] <= 24'd1; // 'a' = 0
            current[1] <= 24'd0; // 'b' = 1
            current[2] <= 24'd0; // 'c' = 2
            current[3] <= 24'd0; // 'd' = 3
            current[4] <= 24'd0; // 'e' = 4
            current[5] <= 24'd0; // 'f' = 5
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (rule_write) begin
                        // Store rule
                        rule_valid[rule_in_idx] <= 1'b1;
                        rule_first[rule_in_idx] <= rule_in_2char[11:6];
                        rule_second[rule_in_idx] <= rule_in_2char[5:0];
                        rule_dest[rule_in_idx] <= rule_in_dest;
                    end else if (start) begin
                        state <= COMPUTE;
                        busy <= 1'b1;
                        loop_count <= n - 3'd1; // n-1 iterations
                        
                        // Initialize next array
                        for (j = 0; j < 6; j = j + 1) begin
                            next[j] <= 24'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Process one rule
                        if (i < 36) begin
                            if (rule_valid[i] && rule_dest[i] == j) begin
                                k <= rule_first[i];
                                next[k] <= next[k] + current[j];
                            end
                            i <= i + 6'd1;
                        end else if (j < 5) begin
                            i <= 6'd0;
                            j <= j + 6'd1;
                        end else begin
                            // Copy next to current
                            for (k = 0; k < 6; k = k + 1) begin
                                current[k] <= next[k];
                            end
                            
                            // Reset for next iteration
                            i <= 6'd0;
                            j <= 6'd0;
                            
                            // Initialize next array
                            for (k = 0; k < 6; k = k + 1) begin
                                next[k] <= 24'd0;
                            end
                            
                            if (loop_count == 3'd0) begin
                                state <= FINISH;
                            end else begin
                                loop_count <= loop_count - 3'd1;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    
                    // Sum all counts
                    result <= current[0] + current[1] + current[2] + current[3] + current[4] + current[5];
                    
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 24'd0;
                end
            endcase
        end
    end

endmodule