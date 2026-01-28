module pattern_matcher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] text [0:15],
    input wire [3:0] length,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] WAIT_A = 3'd1;
    localparam [2:0] WAIT_B1 = 3'd2;
    localparam [2:0] WAIT_B2 = 3'd3;
    localparam [2:0] WAIT_B3 = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] index;           // Current character index
    reg [1:0] b_count;         // Count of consecutive b's seen
    reg pattern_found_reg;     // Registered pattern found flag
    reg [7:0] current_char;    // Current character being checked

    // FSM state transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = WAIT_A;
            end
            
            WAIT_A: begin
                if (index < length) begin
                    if (current_char == 8'h61) begin  // 'a'
                        next_state = WAIT_B1;
                    end else begin
                        next_state = WAIT_A;
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            
            WAIT_B1: begin  // Saw 'a', need first 'b'
                if (index < length) begin
                    if (current_char == 8'h62) begin  // 'b'
                        next_state = WAIT_B2;  // Got ab
                    end else if (current_char == 8'h61) begin  // New 'a'
                        next_state = WAIT_B1;  // Reset count, stay in WAIT_B1
                    end else begin
                        next_state = WAIT_A;   // Break, start over
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            
            WAIT_B2: begin  // Saw 'ab', need second 'b' (2 b's = valid pattern)
                if (index < length) begin
                    if (current_char == 8'h62) begin  // 'b'
                        next_state = WAIT_B3;  // Got abb
                    end else if (current_char == 8'h61) begin  // New 'a'
                        next_state = WAIT_B1;  // Reset, new 'a'
                    end else begin
                        next_state = WAIT_A;   // Break, start over
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            
            WAIT_B3: begin  // Saw 'abb', need third 'b' (3 b's = valid pattern)
                if (index < length) begin
                    if (current_char == 8'h62) begin  // 'b'
                        next_state = FINISH;   // Got abbb, valid pattern!
                    end else if (current_char == 8'h61) begin  // New 'a'
                        next_state = WAIT_B1;  // Reset, new 'a'
                    end else begin
                        next_state = WAIT_A;   // Break, start over
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;  // Return to idle
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            b_count <= 2'd0;
            pattern_found_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (next_state)
                IDLE: begin
                    index <= 4'd0;
                    b_count <= 2'd0;
                    pattern_found_reg <= 1'b0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
                
                WAIT_A: begin
                    if (state != WAIT_A) begin
                        index <= 4'd0;
                        b_count <= 2'd0;
                    end else begin
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                        end
                    end
                end
                
                WAIT_B1: begin
                    if (state != WAIT_B1) begin
                        // Came from WAIT_A or break
                        b_count <= 2'd0;
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                        end
                    end else begin
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                            if (current_char == 8'h61) begin
                                b_count <= 2'd0;  // New 'a', reset count
                            end
                        end
                    end
                end
                
                WAIT_B2: begin
                    if (state != WAIT_B2) begin
                        // Came from WAIT_B1 after seeing 'a'
                        b_count <= 2'd1;
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                        end
                    end else begin
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                            if (current_char == 8'h62) begin
                                b_count <= 2'd2;  // Found 2 b's
                                pattern_found_reg <= 1'b1;
                            end
                        end
                    end
                end
                
                WAIT_B3: begin
                    if (state != WAIT_B3) begin
                        // Came from WAIT_B2 after seeing 'ab'
                        b_count <= 2'd2;
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                        end
                    end else begin
                        if (index < length) begin
                            current_char <= text[index];
                            index <= index + 4'd1;
                            if (current_char == 8'h62) begin
                                b_count <= 2'd3;  // Found 3 b's
                                pattern_found_reg <= 1'b1;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    result <= pattern_found_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    index <= 4'd0;
                    b_count <= 2'd0;
                    pattern_found_reg <= 1'b0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule