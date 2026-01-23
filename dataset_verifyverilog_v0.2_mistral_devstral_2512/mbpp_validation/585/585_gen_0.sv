module top_items_finder (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][63:0] items,
    output reg [2:0] done_items,
    output reg [7:0][63:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SORT1,
        SORT2,
        SORT3,
        SORT4,
        SORT5,
        SORT6,
        OUTPUT,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [7:0][63:0] sorted_items;
    reg [2:0] counter;

    // Compare and swap function
    function automatic void compare_swap(ref reg [63:0] a, ref reg [63:0] b);
        if (a[63:32] < b[63:32]) begin
            reg [63:0] temp;
            temp = a;
            a = b;
            b = temp;
        end
    endfunction

    // Bitonic sort network for 8 items
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            done_items <= 0;
            counter <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = SORT1;
            end
            SORT1: begin
                next_state = SORT2;
            end
            SORT2: begin
                next_state = SORT3;
            end
            SORT3: begin
                next_state = SORT4;
            end
            SORT4: begin
                next_state = SORT5;
            end
            SORT5: begin
                next_state = SORT6;
            end
            SORT6: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // State machine actions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_items <= 0;
            done <= 0;
            counter <= 0;
        end else begin
            case (state)
                LOAD: begin
                    // Load all items
                    for (int i = 0; i < 8; i++) begin
                        sorted_items[i] = items[i];
                    end
                end
                SORT1: begin
                    // Bitonic sort stage 1
                    compare_swap(sorted_items[0], sorted_items[1]);
                    compare_swap(sorted_items[2], sorted_items[3]);
                    compare_swap(sorted_items[4], sorted_items[5]);
                    compare_swap(sorted_items[6], sorted_items[7]);
                end
                SORT2: begin
                    // Bitonic sort stage 2
                    compare_swap(sorted_items[0], sorted_items[2]);
                    compare_swap(sorted_items[1], sorted_items[3]);
                    compare_swap(sorted_items[4], sorted_items[6]);
                    compare_swap(sorted_items[5], sorted_items[7]);
                end
                SORT3: begin
                    // Bitonic sort stage 3
                    compare_swap(sorted_items[0], sorted_items[4]);
                    compare_swap(sorted_items[1], sorted_items[5]);
                    compare_swap(sorted_items[2], sorted_items[6]);
                    compare_swap(sorted_items[3], sorted_items[7]);
                end
                SORT4: begin
                    // Bitonic sort stage 4
                    compare_swap(sorted_items[1], sorted_items[2]);
                    compare_swap(sorted_items[5], sorted_items[6]);
                end
                SORT5: begin
                    // Bitonic sort stage 5
                    compare_swap(sorted_items[0], sorted_items[1]);
                    compare_swap(sorted_items[2], sorted_items[4]);
                    compare_swap(sorted_items[3], sorted_items[5]);
                    compare_swap(sorted_items[6], sorted_items[7]);
                end
                SORT6: begin
                    // Bitonic sort stage 6
                    compare_swap(sorted_items[1], sorted_items[2]);
                    compare_swap(sorted_items[3], sorted_items[4]);
                    compare_swap(sorted_items[5], sorted_items[6]);
                end
                OUTPUT: begin
                    // Output top n items
                    for (int i = 0; i < 8; i++) begin
                        if (i < n) begin
                            result[i] = sorted_items[i];
                        end else begin
                            result[i] = 64'b0;
                        end
                    end
                    done_items = n;
                    done = 1;
                end
                DONE: begin
                    done = 1;
                end
                default: begin
                    done = 0;
                end
            endcase
        end
    end

endmodule