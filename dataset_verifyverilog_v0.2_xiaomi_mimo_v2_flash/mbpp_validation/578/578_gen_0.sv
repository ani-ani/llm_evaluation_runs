module interleave_lists (
    input clk,
    input rst_n,
    input start,
    input [7:0] list1_data,
    input [7:0] list2_data,
    input [7:0] list3_data,
    input list1_valid,
    input list2_valid,
    input list3_valid,
    output reg [7:0] result,
    output reg result_valid,
    output reg done,
    output reg [2:0] rd_en
);

parameter LIST_LEN = 8;

// State encoding
localparam IDLE = 3'b000;
localparam READ_LIST1 = 3'b001;
localparam READ_LIST2 = 3'b010;
localparam READ_LIST3 = 3'b011;
localparam DONE = 3'b100;

reg [2:0] current_state, next_state;
reg [$clog2(LIST_LEN):0] count, next_count; // Counter for elements processed
reg [7:0] stored_data1, stored_data2, stored_data3; // Store captured data
reg output_phase; // Indicates output phase

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        count <= 0;
    end else begin
        current_state <= next_state;
        count <= next_count;
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    next_count = count;
    
    case (current_state)
        IDLE: begin
            if (start) begin
                next_state = READ_LIST1;
                next_count = 0;
            end
        end
        
        READ_LIST1: begin
            if (list1_valid) begin
                next_state = READ_LIST2;
            end
        end
        
        READ_LIST2: begin
            if (list2_valid) begin
                next_state = READ_LIST3;
            end
        end
        
        READ_LIST3: begin
            if (list3_valid) begin
                if (count == LIST_LEN - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = READ_LIST1;
                    next_count = count + 1;
                end
            end
        end
        
        DONE: begin
            // Stay in DONE state until reset
        end
        
        default: begin
            next_state = IDLE;
            next_count = 0;
        end
    endcase
end

// Output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result <= 8'b0;
        result_valid <= 1'b0;
        done <= 1'b0;
        rd_en <= 3'b000;
        stored_data1 <= 8'b0;
        stored_data2 <= 8'b0;
        stored_data3 <= 8'b0;
        output_phase <= 1'b0;
    end else begin
        // Default values
        result_valid <= 1'b0;
        rd_en <= 3'b000;
        done <= 1'b0;
        
        case (current_state)
            IDLE: begin
                // Nothing to do
            end
            
            READ_LIST1: begin
                rd_en[0] <= 1'b1;
                if (list1_valid) begin
                    stored_data1 <= list1_data;
                    result <= list1_data;
                    result_valid <= 1'b1;
                end
            end
            
            READ_LIST2: begin
                rd_en[1] <= 1'b1;
                if (list2_valid) begin
                    stored_data2 <= list2_data;
                    result <= list2_data;
                    result_valid <= 1'b1;
                end
            end
            
            READ_LIST3: begin
                rd_en[2] <= 1'b1;
                if (list3_valid) begin
                    stored_data3 <= list3_data;
                    result <= list3_data;
                    result_valid <= 1'b1;
                end
            end
            
            DONE: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule