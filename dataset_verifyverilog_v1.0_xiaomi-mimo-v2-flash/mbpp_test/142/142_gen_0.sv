module CountIdenticalElements(
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [7:0] list3 [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] counter;
    reg [2:0] position;
    wire [7:0] position_match;
    wire [7:0] new_counter;

    // Combinational comparison for each position
    assign position_match[0] = (list1[0] == list2[0]) && (list1[0] == list3[0]);
    assign position_match[1] = (list1[1] == list2[1]) && (list1[1] == list3[1]);
    assign position_match[2] = (list1[2] == list2[2]) && (list1[2] == list3[2]);
    assign position_match[3] = (list1[3] == list2[3]) && (list1[3] == list3[3]);
    assign position_match[4] = (list1[4] == list2[4]) && (list1[4] == list3[4]);
    assign position_match[5] = (list1[5] == list2[5]) && (list1[5] == list3[5]);
    assign position_match[6] = (list1[6] == list2[6]) && (list1[6] == list3[6]);
    assign position_match[7] = (list1[7] == list2[7]) && (list1[7] == list3[7]);

    // Sequential comparison logic
    always @(*) begin
        case (position)
            3'd0: new_counter = counter + {7'd0, position_match[0]};
            3'd1: new_counter = counter + {7'd0, position_match[1]};
            3'd2: new_counter = counter + {7'd0, position_match[2]};
            3'd3: new_counter = counter + {7'd0, position_match[3]};
            3'd4: new_counter = counter + {7'd0, position_match[4]};
            3'd5: new_counter = counter + {7'd0, position_match[5]};
            3'd6: new_counter = counter + {7'd0, position_match[6]};
            3'd7: new_counter = counter + {7'd0, position_match[7]};
            default: new_counter = counter;
        endcase
    end

    // Next state and output logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPARE;
                else
                    next_state = IDLE;
            end
            COMPARE: begin
                if (position == 3'd7)
                    next_state = DONE_STATE;
                else
                    next_state = COMPARE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 8'd0;
            position <= 3'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    position <= 3'd0;
                end
                COMPARE: begin
                    counter <= new_counter;
                    position <= position + 3'd1;
                end
                DONE_STATE: begin
                    result <= counter;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule