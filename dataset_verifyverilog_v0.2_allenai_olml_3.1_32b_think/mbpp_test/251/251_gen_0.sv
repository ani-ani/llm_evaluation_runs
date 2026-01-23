module insert_element (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] element,
    input [7:0] list_data [0:7],
    input [2:0] list_len,
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg done
);

// Internal registers
reg [7:0] reg_element;
reg [7:0] reg_list_data [0:7];
reg [2:0] reg_list_len;
reg [3:0] reg_result_len;
reg [1:0] state;
reg [3:0] count; // count from 0 to 15, then 16?

// Temporary result for computation
reg [7:0] temp_result [0:15];

// State definitions
localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;

always @(posedge clk) begin
    // Reset handling
    if (!rst_n) begin
        reg_element <= 0;
        reg_list_data <= 0;
        reg_list_len <=0;
        reg_result_len <=0;
        state <= IDLE;
        count <=0;
        done <=0;
        result <=0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                // Capture inputs
                reg_element <= element;
                reg_list_data <= list_data;
                reg_list_len <= list_len;
                reg_result_len <= reg_list_len << 1; // 2 * list_len
                state <= PROCESSING;
                count <= 0; // Start counting from 0
                done <=0;
            end
        end else if (state == PROCESSING) begin
            if (count < 16) begin
                count <= count +1;
            end else begin
                // Compute temp_result
                temp_result[0] = (reg_result_len >0) ? reg_element : 0;
                temp_result[1] = (reg_result_len >1) ? reg_list_data[0] : 0;
                temp_result[2] = (reg_result_len >2) ? reg_element : 0;
                temp_result[3] = (reg_result_len >3) ? reg_list_data[1] : 0;
                temp_result[4] = (reg_result_len >4) ? reg_element : 0;
                temp_result[5] = (reg_result_len >5) ? reg_list_data[2] : 0;
                temp_result[6] = (reg_result_len >6) ? reg_element : 0;
                temp_result[7] = (reg_result_len >7) ? reg_list_data[3] : 0;
                temp_result[8] = (reg_result_len >8) ? reg_element : 0;
                temp_result[9] = (reg_result_len >9) ? reg_list_data[4] : 0;
                temp_result[10] = (reg_result_len >10) ? reg_element : 0;
                temp_result[11] = (reg_result_len >11) ? reg_list_data[5] : 0;
                temp_result[12] = (reg_result_len >12) ? reg_element : 0;
                temp_result[13] = (reg_result_len >13) ? reg_list_data[6] : 0;
                temp_result[14] = (reg_result_len >14) ? reg_element : 0;
                temp_result[15] = (reg_result_len >15) ? reg_list_data[7] : 0;
                // Load result and move to DONE
                result <= temp_result;
                state <= DONE;
            end
        end else if (state == DONE) begin
            // Do nothing
        end
    end
end

// Combinational assignments
assign done = state == DONE;
assign result_len = reg_result_len;

endmodule