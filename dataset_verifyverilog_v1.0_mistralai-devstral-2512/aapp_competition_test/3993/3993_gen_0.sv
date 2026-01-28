module discard_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] p [0:1023],
    input wire [9:0] m_valid,
    input wire [7:0] k_in,
    output reg done,
    output reg [9:0] result
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [9:0] i;                // Index counter (0 to 1023)
    reg [31:0] shift;           // Accumulated shift (32-bit for safety)
    reg [9:0] ops_count;        // Operation count (10-bit)
    reg [15:0] prev_page;       // Previous page number (16-bit)
    reg [15:0] current_page;    // Current page number (16-bit)
    reg [15:0] idx;             // Current index from p[i]

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 10'd0;
            shift <= 32'd0;
            ops_count <= 10'd0;
            prev_page <= 16'd0;
            current_page <= 16'd0;
            idx <= 16'd0;
            done <= 1'b0;
            result <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        i <= 10'd0;
                        shift <= 32'd0;
                        ops_count <= 10'd0;
                        prev_page <= 16'd0;
                    end
                end

                PROCESS: begin
                    // Read current index
                    idx <= p[i];

                    // Calculate current page
                    current_page <= (idx - shift) / k_in;

                    // Check if this is the first item or page changed
                    if (i == 10'd0 || current_page != prev_page) begin
                        ops_count <= ops_count + 10'd1;
                    end

                    // Update shift (one item removed)
                    shift <= shift + 32'd1;

                    // Update previous page
                    prev_page <= current_page;

                    // Move to next index
                    if (i == m_valid - 10'd1) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 10'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= ops_count;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule