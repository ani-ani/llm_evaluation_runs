module CommonElementFinder (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    input [3:0] len1,
    input [3:0] len2,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LEN = 3'd1;
    localparam [2:0] INIT_OUTER = 3'd2;
    localparam [2:0] CHECK_OUTER = 3'd3;
    localparam [2:0] INIT_INNER = 3'd4;
    localparam [2:0] CHECK_INNER = 3'd5;
    localparam [2:0] COMPARE = 3'd6;
    localparam [2:0] FOUND = 3'd7;
    localparam [2:0] NOT_FOUND = 3'd8;
    localparam [2:0] DONE_STATE = 3'd9;
    
    reg [3:0] state, next_state;
    reg [3:0] i;  // outer loop counter
    reg [3:0] j;  // inner loop counter
    reg found;
    reg [7:0] current_val;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK_LEN : IDLE;
            CHECK_LEN: begin
                if ((len1 == 4'd0) || (len2 == 4'd0)) begin
                    next_state = NOT_FOUND;
                end else begin
                    next_state = INIT_OUTER;
                end
            end
            INIT_OUTER: next_state = CHECK_OUTER;
            CHECK_OUTER: begin
                if (i < len1) begin
                    next_state = INIT_INNER;
                end else begin
                    next_state = NOT_FOUND;
                end
            end
            INIT_INNER: next_state = CHECK_INNER;
            CHECK_INNER: begin
                if (j < len2) begin
                    next_state = COMPARE;
                end else begin
                    next_state = INIT_OUTER;
                end
            end
            COMPARE: begin
                if (arr1[i] == arr2[j]) begin
                    next_state = FOUND;
                end else begin
                    next_state = CHECK_INNER;
                end
            end
            FOUND: next_state = DONE_STATE;
            NOT_FOUND: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            found <= 1'b0;
            current_val <= 8'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    found <= 1'b0;
                    cycle_count <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                end
                
                INIT_OUTER: begin
                    i <= 4'd0;
                end
                
                CHECK_OUTER: begin
                    // Check if counter is within bounds
                end
                
                INIT_INNER: begin
                    j <= 4'd0;
                    current_val <= arr1[i];
                end
                
                CHECK_INNER: begin
                    // Check if counter is within bounds
                end
                
                COMPARE: begin
                    j <= j + 4'd1;
                    if (arr1[i] == arr2[j]) begin
                        found <= 1'b1;
                    end
                end
                
                FOUND: begin
                    result <= 1'b1;
                    i <= len1;  // Force outer loop exit
                    j <= len2;  // Force inner loop exit
                end
                
                NOT_FOUND: begin
                    result <= 1'b0;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count >= 4'd1) begin
                        done <= 1'b0;
                    end
                end
            endcase
            
            // Increment counters in appropriate states
            if (state == CHECK_OUTER) begin
                if (next_state == INIT_INNER) begin
                    i <= i + 4'd1;
                end
            end
            
            // Safety timeout
            if (cycle_count > MAX_CYCLES) begin
                state <= DONE_STATE;
                done <= 1'b0;
                result <= 1'b0;
            end
        end
    end
endmodule