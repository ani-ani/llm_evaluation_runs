module next_tolerable_string(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] p,
    input wire [4:0] s_in [0:15],
    output reg [4:0] result [0:15],
    output reg valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FIND_POSITION = 4'd1;
    localparam [3:0] INCREMENT = 4'd2;
    localparam [3:0] CHECK_CONSTRAINT = 4'd3;
    localparam [3:0] FILL_REMAINING = 4'd4;
    localparam [3:0] DONE = 4'd5;

    reg [3:0] state;
    reg [3:0] current_pos;
    reg [4:0] current_val;
    reg [4:0] working_string [0:15];
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2000;

    // Initialize working string
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_pos <= 4'd0;
            current_val <= 5'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 12'd0;
            for (i = 0; i < 16; i = i + 1) begin
                working_string[i] <= 5'd0;
                result[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start) begin
                        // Copy input to working string
                        for (i = 0; i < 16; i = i + 1) begin
                            working_string[i] <= s_in[i];
                        end
                        current_pos <= n - 4'd1;
                        state <= FIND_POSITION;
                    end
                end

                FIND_POSITION: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (current_pos < 4'd0) begin
                        // No valid position found
                        valid <= 1'b0;
                        state <= DONE;
                    end else begin
                        current_val <= working_string[current_pos] + 5'd1;
                        state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (current_val >= p) begin
                        // Try previous position
                        current_pos <= current_pos - 4'd1;
                        state <= FIND_POSITION;
                    end else begin
                        state <= CHECK_CONSTRAINT;
                    end
                end

                CHECK_CONSTRAINT: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        reg constraint_ok;
                        constraint_ok = 1'b1;
                        
                        // Check against previous character
                        if (current_pos > 4'd0 && current_val == working_string[current_pos - 4'd1]) begin
                            constraint_ok = 1'b0;
                        end
                        
                        // Check against character two positions back
                        if (current_pos > 4'd1 && current_val == working_string[current_pos - 4'd2]) begin
                            constraint_ok = 1'b0;
                        end
                        
                        if (constraint_ok) begin
                            working_string[current_pos] <= current_val;
                            state <= FILL_REMAINING;
                        end else begin
                            current_val <= current_val + 5'd1;
                            state <= INCREMENT;
                        end
                    end
                end

                FILL_REMAINING: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        reg [3:0] j;
                        reg [4:0] prev1, prev2;
                        reg [4:0] fill_val;
                        
                        // Fill positions from current_pos+1 to n-1
                        for (j = current_pos + 4'd1; j < n; j = j + 4'd1) begin
                            prev1 = (j > 4'd0) ? working_string[j - 4'd1] : 5'd0;
                            prev2 = (j > 4'd1) ? working_string[j - 4'd2] : 5'd0;
                            
                            fill_val = 5'd0;
                            while (fill_val < p) begin
                                if (fill_val != prev1 && (j < 4'd2 || fill_val != prev2)) begin
                                    working_string[j] <= fill_val;
                                    break;
                                end
                                fill_val = fill_val + 5'd1;
                            end
                            
                            if (fill_val >= p) begin
                                // Couldn't fill - invalid
                                valid <= 1'b0;
                                state <= DONE;
                                break;
                            end
                        end
                        
                        if (j >= n) begin
                            // Successfully filled all positions
                            valid <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Copy working string to result
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] <= working_string[i];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule