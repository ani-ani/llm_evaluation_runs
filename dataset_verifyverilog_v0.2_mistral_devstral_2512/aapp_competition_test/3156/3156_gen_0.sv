module shopping_path_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_stores,
    input [2:0] num_items,
    input [2:0] purchase_order [0:7],
    input [7:0] inventory_matrix [0:7],
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] CHECK_PATH = 2'b01;
    localparam [1:0] EVALUATE = 2'b10;
    localparam [1:0] DONE = 2'b11;

    reg [1:0] state;
    reg [2:0] current_store;
    reg [2:0] current_item;
    reg [2:0] path_count;
    reg [2:0] path_stack [0:7];
    reg [2:0] stack_ptr;
    reg [2:0] store_idx;
    reg [2:0] item_idx;
    reg valid_path;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_store <= 0;
            current_item <= 0;
            path_count <= 0;
            stack_ptr <= 0;
            store_idx <= 0;
            item_idx <= 0;
            valid_path <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK_PATH;
                        current_store <= 0;
                        current_item <= 0;
                        path_count <= 0;
                        stack_ptr <= 0;
                        store_idx <= 0;
                        item_idx <= 0;
                        valid_path <= 0;
                        result <= 0;
                        done <= 0;
                    end
                end
                CHECK_PATH: begin
                    if (item_idx == num_items) begin
                        path_count <= path_count + 1;
                        if (path_count >= 2) begin
                            state <= DONE;
                            result <= 2'b10;
                            done <= 1;
                        end else begin
                            state <= EVALUATE;
                        end
                    end else begin
                        if (inventory_matrix[current_store][purchase_order[item_idx]]) begin
                            path_stack[stack_ptr] <= current_store;
                            stack_ptr <= stack_ptr + 1;
                            item_idx <= item_idx + 1;
                            current_store <= 0;
                        end else begin
                            current_store <= current_store + 1;
                            if (current_store == num_stores) begin
                                if (stack_ptr == 0) begin
                                    state <= EVALUATE;
                                end else begin
                                    stack_ptr <= stack_ptr - 1;
                                    current_store <= path_stack[stack_ptr] + 1;
                                    item_idx <= item_idx - 1;
                                end
                            end
                        end
                    end
                end
                EVALUATE: begin
                    if (path_count == 0) begin
                        result <= 2'b00;
                    end else if (path_count == 1) begin
                        result <= 2'b01;
                    end else begin
                        result <= 2'b10;
                    end
                    done <= 1;
                    state <= DONE;
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule