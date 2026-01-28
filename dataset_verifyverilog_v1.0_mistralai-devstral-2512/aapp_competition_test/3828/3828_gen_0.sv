module min_moves_to_sort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] p [0:15],
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_POS  = 3'd1;
    localparam [2:0] FIND_SEQ  = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Position memory: pos[v] = position of value v (1-16)
    reg [3:0] pos [0:15];
    
    // Sequence tracking
    reg [3:0] current_len;
    reg [3:0] max_len;
    reg [3:0] v;
    reg [3:0] prev_pos;
    reg [3:0] curr_pos;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            
            // Initialize position memory
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                pos[i] <= 4'd0;
            end
            
            // Initialize sequence tracking
            current_len <= 4'd0;
            max_len <= 4'd0;
            v <= 4'd0;
            prev_pos <= 4'd0;
            curr_pos <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_POS;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD_POS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Load positions: pos[p[i]-1] = i
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        pos[p[i] - 4'd1] <= 4'd0 + i;
                    end
                    
                    next_state <= FIND_SEQ;
                end
                
                FIND_SEQ: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (v == 4'd0) begin
                        // Initialize for v=1
                        v <= 4'd1;
                        prev_pos <= pos[0];
                        current_len <= 4'd1;
                        max_len <= 4'd1;
                    end else begin
                        curr_pos <= pos[v - 4'd1];
                        
                        if (curr_pos > prev_pos) begin
                            current_len <= current_len + 4'd1;
                            if (current_len > max_len) begin
                                max_len <= current_len;
                            end
                        end else begin
                            current_len <= 4'd1;
                        end
                        
                        prev_pos <= curr_pos;
                        v <= v + 4'd1;
                        
                        if (v == 4'd16) begin
                            next_state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= 8'd16 - max_len;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule