module InterleaveLists(
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [7:0] list3 [0:7],
    input [3:0] length,
    output reg [7:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] FETCH_LIST1 = 3'd1;
    localparam [2:0] FETCH_LIST2 = 3'd2;
    localparam [2:0] FETCH_LIST3 = 3'd3;
    localparam [2:0] DONE_STATE  = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [1:0] list_selector;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            list_selector <= 2'd0;
            result <= 8'd0;
            done <= 1'b0;
            ready <= 1'b1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        list_selector <= 2'd0;
                        next_state <= FETCH_LIST1;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                FETCH_LIST1: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    result <= list1[index];
                    next_state <= FETCH_LIST2;
                end
                
                FETCH_LIST2: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    result <= list2[index];
                    next_state <= FETCH_LIST3;
                end
                
                FETCH_LIST3: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    result <= list3[index];
                    if (index == length - 1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        index <= index + 1;
                        next_state <= FETCH_LIST1;
                    end
                end
                
                DONE_STATE: begin
                    ready <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b1;
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

endmodule