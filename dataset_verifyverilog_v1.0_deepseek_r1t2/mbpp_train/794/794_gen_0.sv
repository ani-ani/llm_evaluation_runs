module String_Matcher (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input str_end,
    output reg match,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SEARCH_A  = 3'd1;
    localparam [2:0] SEARCH_B  = 3'd2;
    localparam [2:0] MATCH     = 3'd3;
    localparam [2:0] NO_MATCH  = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    match <= 1'b0;
                    done <= 1'b0;
                    if (start) state <= SEARCH_A;
                end
                
                SEARCH_A: begin
                    if (char_valid) begin
                        if (char_in == 8'h61) begin          // 'a'
                            state <= SEARCH_B;
                        end else if (str_end) begin
                            state <= NO_MATCH;
                        end
                    end else if (str_end) begin
                        state <= NO_MATCH;
                    end
                end
                
                SEARCH_B: begin
                    if (char_valid && str_end) begin
                        if (char_in == 8'h62) begin          // 'b'
                            state <= MATCH;
                        end else begin
                            state <= NO_MATCH;
                        end
                    end else if (str_end) begin
                        state <= NO_MATCH;
                    end
                end
                
                MATCH: begin
                    match <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                NO_MATCH: begin
                    match <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule