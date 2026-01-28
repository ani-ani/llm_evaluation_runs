module TopModule(
    input clk,
    input rst_n,
    input start,
    input items_valid,
    input [63:0] item_data,
    input [15:0] item_price,
    input [3:0] n,
    input [3:0] item_index,
    output reg [7:0] result_name_0,
    output reg [7:0] result_name_1,
    output reg [7:0] result_name_2,
    output reg [7:0] result_name_3,
    output reg [7:0] result_name_4,
    output reg [7:0] result_name_5,
    output reg [7:0] result_name_6,
    output reg [7:0] result_name_7,
    output reg [15:0] result_price_0,
    output reg [15:0] result_price_1,
    output reg [15:0] result_price_2,
    output reg [15:0] result_price_3,
    output reg [15:0] result_price_4,
    output reg [15:0] result_price_5,
    output reg [15:0] result_price_6,
    output reg [15:0] result_price_7,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INPUT   = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Internal storage for items
    reg [63:0] item_storage_name [0:15];
    reg [15:0] item_storage_price [0:15];
    reg [3:0] item_count;

    // Sorting variables
    reg [3:0] i, j;
    reg [15:0] temp_price;
    reg [63:0] temp_name;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            item_count <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;
            
            // Clear internal storage
            for (i = 0; i < 16; i = i + 1) begin
                item_storage_name[i] <= 64'd0;
                item_storage_price[i] <= 16'd0;
            end
            
            // Clear output registers
            result_name_0 <= 8'd0;
            result_name_1 <= 8'd0;
            result_name_2 <= 8'd0;
            result_name_3 <= 8'd0;
            result_name_4 <= 8'd0;
            result_name_5 <= 8'd0;
            result_name_6 <= 8'd0;
            result_name_7 <= 8'd0;
            result_price_0 <= 16'd0;
            result_price_1 <= 16'd0;
            result_price_2 <= 16'd0;
            result_price_3 <= 16'd0;
            result_price_4 <= 16'd0;
            result_price_5 <= 16'd0;
            result_price_6 <= 16'd0;
            result_price_7 <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INPUT;
                        busy <= 1'b1;
                        item_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INPUT: begin
                    if (items_valid) begin
                        item_storage_name[item_index] <= item_data;
                        item_storage_price[item_index] <= item_price;
                        if (item_index == 4'd15) begin
                            next_state <= SORT;
                        end
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (item_storage_price[j] < item_storage_price[j + 1]) begin
                                // Swap prices
                                temp_price <= item_storage_price[j];
                                item_storage_price[j] <= item_storage_price[j + 1];
                                item_storage_price[j + 1] <= temp_price;
                                
                                // Swap names
                                temp_name <= item_storage_name[j];
                                item_storage_name[j] <= item_storage_name[j + 1];
                                item_storage_name[j + 1] <= temp_name;
                            end
                        end
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    // Copy top n items to output
                    result_name_0 <= item_storage_name[0][7:0];
                    result_name_1 <= item_storage_name[1][7:0];
                    result_name_2 <= item_storage_name[2][7:0];
                    result_name_3 <= item_storage_name[3][7:0];
                    result_name_4 <= item_storage_name[4][7:0];
                    result_name_5 <= item_storage_name[5][7:0];
                    result_name_6 <= item_storage_name[6][7:0];
                    result_name_7 <= item_storage_name[7][7:0];
                    
                    result_price_0 <= item_storage_price[0];
                    result_price_1 <= item_storage_price[1];
                    result_price_2 <= item_storage_price[2];
                    result_price_3 <= item_storage_price[3];
                    result_price_4 <= item_storage_price[4];
                    result_price_5 <= item_storage_price[5];
                    result_price_6 <= item_storage_price[6];
                    result_price_7 <= item_storage_price[7];
                    
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for safety
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            end
        end
    end

endmodule