module frequency_counter (
    input clk,
    input rst_n,
    input start,
    input [2:0] row_idx,
    input [7:0] data_in [7:0],
    output reg [7:0] freq_value,
    output reg [7:0] key_out,
    output reg done,
    output reg valid
);

    // Parameters
    parameter NUM_ROWS = 3;
    parameter ELEMENTS_PER_ROW = 8;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD_ROW = 3'b001;
    localparam COUNTING = 3'b010;
    localparam READOUT = 3'b011;
    localparam FINISHED = 3'b100;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [7:0] ram_addr;
    reg [7:0] ram_din;
    reg ram_we;
    reg [7:0] key_reg;
    reg [7:0] row_buffer [7:0];
    reg [3:0] element_cnt;
    reg [2:0] row_cnt;
    reg processing_flag;
    reg reading_flag;

    // Internal RAM (256 x 8 bits)
    reg [7:0] mem [0:255];

    // Combinational Logic for RAM Read
    // Read logic is combinational for the current address
    wire [7:0] ram_dout;
    assign ram_dout = mem[ram_addr];

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Logic
            ram_addr <= 8'h00;
            ram_din <= 8'h00;
            ram_we <= 1'b0;
            key_out <= 8'h00;
            freq_value <= 8'h00;
            done <= 1'b0;
            valid <= 1'b0;
            element_cnt <= 4'd0;
            row_cnt <= 3'd0;
            key_reg <= 8'h00;
            processing_flag <= 1'b0;
            reading_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    ram_we <= 1'b0;
                    processing_flag <= 1'b0;
                    reading_flag <= 1'b0;
                    element_cnt <= 4'd0;
                    row_cnt <= 3'd0;
                    if (start) begin
                        // Start loading the first row.
                        row_cnt <= 3'd0;
                        next_state <= LOAD_ROW;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD_ROW: begin
                    // Check if the external row_idx matches the row we want to process
                    if (row_idx == row_cnt) begin
                        // Latch data_in to row_buffer
                        row_buffer[0] <= data_in[0];
                        row_buffer[1] <= data_in[1];
                        row_buffer[2] <= data_in[2];
                        row_buffer[3] <= data_in[3];
                        row_buffer[4] <= data_in[4];
                        row_buffer[5] <= data_in[5];
                        row_buffer[6] <= data_in[6];
                        row_buffer[7] <= data_in[7];
                        element_cnt <= 4'd0;
                        next_state <= COUNTING;
                    end else begin
                        next_state <= LOAD_ROW;
                    end
                end

                COUNTING: begin
                    // Process one element per cycle
                    if (element_cnt < ELEMENTS_PER_ROW) begin
                        // Read current count from RAM
                        ram_addr <= row_buffer[element_cnt];
                        ram_din <= ram_dout + 1; // Increment current value
                        ram_we <= 1'b1; // Write enable
                        element_cnt <= element_cnt + 1;
                    end else begin
                        ram_we <= 1'b0; // Stop writing
                        if (row_cnt < NUM_ROWS - 1) begin
                            row_cnt <= row_cnt + 1;
                            next_state <= LOAD_ROW;
                        end else begin
                            next_state <= FINISHED;
                        end
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    if (reading_flag) begin
                        next_state <= READOUT;
                    end else begin
                        next_state <= FINISHED;
                    end
                end

                READOUT: begin
                    // Iterate through all 256 keys
                    if (key_out < 255) begin
                        key_out <= key_out + 1;
                        freq_value <= mem[key_out];
                        valid <= 1'b1;
                    end else begin
                        key_out <= 8'h00;
                        valid <= 1'b0;
                        next_state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule